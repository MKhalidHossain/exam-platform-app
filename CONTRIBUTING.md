# Contributing Guide

Thanks for contributing to this Flutter project.

## Before you start

- Review the existing issue tracker before opening a new issue or pull request.
- For significant changes, start with an issue so the direction is aligned before implementation.
- Keep each pull request focused on one concern. Small, reviewable changes are preferred.

## Local setup

1. Install the current stable Flutter SDK.
2. Run `flutter pub get` from the repository root.
3. Configure the runtime constants in `lib/utils/app_constants.dart`.
4. Start the app with `flutter run`.

## Development standards

- Follow the existing project structure under `controllers`, `models`, `services`, `routes`, `utils`, and `views`.
- Prefer small widgets, clear service boundaries, and explicit state transitions in controllers.
- Keep platform-specific changes isolated to the relevant `android`, `ios`, `macos`, `linux`, `windows`, or `web` directories.
- Do not commit secrets, production keys, or private endpoints beyond the agreed configuration surface.

## Validation

Run the following checks before opening a pull request:

```bash
flutter analyze
flutter test
```

If your change affects UI, deep links, payments, or auth, add manual verification notes to the pull request.

## Pull request expectations

- Explain the user-facing outcome, not only the code change.
- Link related issues when applicable.
- Add screenshots or screen recordings for visible UI changes.
- Call out any migration, environment, or release implications explicitly.
