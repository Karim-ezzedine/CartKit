# Contributing to CartKit

## Branch and merge policy

- Do not push commits directly to `main`.
- Open a pull request for all changes targeting `main`.
- Merging to `main` requires:
  - At least one approval.
  - A code owner approval.
  - All required CI checks to pass.
- Administrators can bypass branch protection for solo-maintainer operation.
- Release tags (for example `v2.0.2`) are restricted to maintainers/admins.
- Release tags must point to commits already merged into `main`.

## Development flow

1. Fork the repository and create a feature branch.
2. Make changes with focused commits.
3. Run tests locally before opening a pull request:
   - `swift test -v`
4. Open a pull request using the repository template.
5. Address review feedback and keep CI green.

## Pull request expectations

- Keep pull requests small and focused.
- Include clear motivation and risk in the description.
- Update docs when behavior or API changes.
- Add or update tests for behavior changes.

## Commit message guidance

- Use clear, imperative subjects.
- Prefer one logical change per commit.

## Versioning and releases

- This project follows semantic versioning.
- Maintainers create and push release tags (`vMAJOR.MINOR.PATCH`) after merge to `main`.
