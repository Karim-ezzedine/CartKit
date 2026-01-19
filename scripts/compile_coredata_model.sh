#!/bin/bash
set -euo pipefail

# Compiles the Core Data source model (.xcdatamodeld) into a runtime model bundle (.momd).
# Why: `swift test` (SwiftPM) does not reliably compile/bundle .xcdatamodeld, which can cause
# `modelNotFound("CartStorage")` or schema drift in CI. This keeps the compiled model in sync.

MODEL_SRC="Sources/CartKitStorageCoreData/Resources/CartStorage.xcdatamodeld"
MODEL_OUT="Sources/CartKitStorageCoreData/Resources/CartStorage.momd"

# Remove any previously compiled model to avoid stale artifacts.
rm -rf "$MODEL_OUT"

# Compile the model using Apple's Core Data model compiler (momc).
xcrun momc "$MODEL_SRC" "$MODEL_OUT"

echo "Compiled Core Data model: $MODEL_SRC -> $MODEL_OUT"
