# Contributing to VOID LAN

## Setup

```bash
git clone <your-fork-url>
cd void_lan
flutter create --platforms=windows,linux .
flutter pub get
```

Run `flutter analyze` and `flutter test` before opening a PR — CI runs
the same two commands.

## Branching

- Branch from `main`: `feature/<short-description>` or `fix/<short-description>`.
- Keep PRs scoped to one feature or fix; large mixed PRs are harder to review and revert.

## Code style

- `flutter_lints` is enforced via `analysis_options.yaml`; fix warnings rather than suppressing them.
- Prefer `const` constructors and immutable models.
- Comments explain *why*, not *what* — if a comment just restates the code, delete it instead.
- New services go in `lib/data/services/`, new screens in `lib/presentation/<feature>/`, matching the existing feature-first layout described in the README.

## Networking/security changes

Anything touching `lib/data/services/` (sockets, pairing, transfer) gets
extra scrutiny — please describe the wire-format or trust-model impact
in the PR description, not just the code diff.

## Reporting issues

Include your platform (Windows/Android/Linux), Flutter version
(`flutter --version`), and steps to reproduce. For networking issues,
note whether both devices are on the same subnet and whether a
firewall could be blocking ports 58201–58203 (see README).
