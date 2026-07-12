# Contributing to VOID LAN

Thank you for contributing.

## Development Rules

Before submitting changes:

1. Create a separate branch.
2. Keep commits small and descriptive.
3. Test changes locally.
4. Follow Dart and Flutter style guidelines.

Example:


feature/file-transfer
fix/network-discovery
docs/security-update


## Pull Requests

Pull requests should include:

- Clear description of changes
- Reason for the change
- Testing information
- Screenshots (for UI changes)

## Code Quality

Requirements:

- No unused dependencies
- No hardcoded secrets
- No breaking API changes without discussion
- Keep offline-first principles

## Concurrency and Networking

VOID LAN is designed for LAN environments.

Contributors should consider:

- Thread safety
- Race conditions
- Concurrent file transfers
- Network failures
- Data consistency

## Review Process

All changes are reviewed before merging.

Maintainers may request:

- Code changes
- Additional tests
- Documentation updates

## Code of Conduct

Be respectful and constructive.
Harassment or malicious contributions are not accepted.
