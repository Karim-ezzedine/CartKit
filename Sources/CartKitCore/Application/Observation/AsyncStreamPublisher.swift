import Combine
import Foundation

/// Bridges an `AsyncStream` into a Combine `Publisher`.
///
/// - Values are delivered on the main queue.
/// - Swift 6 safe: avoids capturing generic `Subscriber` types inside `Task` closures.
public struct AsyncStreamPublisher<Output: Sendable>: Publisher {
    public typealias Failure = Never
    
    private let stream: AsyncStream<Output>
    
    public init(_ stream: AsyncStream<Output>) {
        self.stream = stream
    }
    
    public func receive<S: Subscriber>(subscriber: S)
    where S.Input == Output, S.Failure == Never {
        let subscription = StreamSubscription(stream: stream, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
    
    private final class StreamSubscription<S: Subscriber>: Subscription
    where S.Input == Output, S.Failure == Never {
        
        private let box: AnySubscriberBox<Output>
        private var task: Task<Void, Never>?
        
        init(stream: AsyncStream<Output>, subscriber: S) {
            self.box = AnySubscriberBox(subscriber)
            
            // Capture only `stream` and the type-erased box in the Task closure.
            let box = self.box
            let stream = stream
            
            self.task = Task {
                var iterator = stream.makeAsyncIterator()
                while let value = await iterator.next() {
                    box.deliver(value)
                }
                box.finish()
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            // Demand is not enforced for this lightweight bridge.
        }
        
        func cancel() {
            task?.cancel()
            task = nil
            box.clear()
        }
    }
    
    /// Type-erased subscriber box.
    ///
    /// Marked `@unchecked Sendable` because it synchronizes internal state and ensures
    /// the subscriber is only invoked on the main queue.
    private final class AnySubscriberBox<Element: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        
        private var onValue: ((Element) -> Void)?
        private var onFinish: (() -> Void)?
        
        init<S: Subscriber>(_ subscriber: S) where S.Input == Element, S.Failure == Never {
            let subscriber = subscriber
            
            self.onValue = { value in
                _ = subscriber.receive(value)
            }
            self.onFinish = {
                subscriber.receive(completion: .finished)
            }
        }
        
        func clear() {
            lock.lock()
            onValue = nil
            onFinish = nil
            lock.unlock()
        }
        
        func deliver(_ value: Element) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.lock.lock()
                let onValue = self.onValue
                self.lock.unlock()
                
                onValue?(value)
            }
        }
        
        func finish() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.lock.lock()
                let onFinish = self.onFinish
                self.lock.unlock()
                
                onFinish?()
            }
        }
    }
    
}
