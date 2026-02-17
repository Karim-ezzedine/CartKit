## Summary

- What changed:
- Why:
- Risk level: low / medium / high

## Validation

- [ ] `swift build`
- [ ] `swift test -v`
- [ ] CI-equivalent scripts executed when configured by workflow policy

## Public API Safety (Required)

- [ ] I checked the public API baseline and this PR does **not** break public API signatures
- [ ] If this PR changes public API, I documented it as breaking and linked migration notes
- [ ] I verified Demo app/API call sites continue to compile (or documented required updates)

## Architecture Checklist

- [ ] Changes preserve dependency direction (Core depends on ports, infra implements adapters)
- [ ] New duplication was avoided or intentionally justified
- [ ] Docs/comments are updated to match behavior
