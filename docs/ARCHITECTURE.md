# Architecture Overview

## Product scope

This repository contains a Flutter application for inspector exam preparation. The app combines onboarding, authentication, exam unlocks, paid resources, quiz sessions, referral flows, and user performance tracking in a single mobile codebase.

## Application shape

The project follows a presentation-first Flutter structure backed by controllers and services:

```text
lib/
├── controllers/   # GetX controllers and app state orchestration
├── core/          # Shared error types and cross-cutting logic
├── models/        # API payloads and domain entities
├── routes/        # GoRouter route registration
├── services/      # HTTP, auth, exam, referral, ebook, and storage services
├── utils/         # Constants, themes, colors, and navigation helpers
└── views/         # Screens and reusable UI widgets
```

## State and navigation

- `GetX` is used for controller lifecycle and reactive state.
- `GoRouter` is used for route definitions and screen transitions.
- Theme, auth, splash behavior, home data, history, and profile state are coordinated through dedicated controllers.

## Data flow

1. A screen triggers a user action.
2. The relevant controller or screen-level logic calls a service.
3. The service performs API or local-storage work.
4. Parsed models are returned to the caller.
5. UI updates are rendered through controller state or direct widget state.

This keeps API access and persistence logic out of widget trees while keeping feature flow readable.

## External integrations

- `http` powers backend API communication.
- `shared_preferences` and `flutter_secure_storage` persist local session and installation data.
- `flutter_stripe` supports payment and unlock flows.
- `app_links` handles referral and shared-link entry points.
- `syncfusion_flutter_pdfviewer` renders in-app PDF content.
- `image_picker`, `share_plus`, `url_launcher`, `lottie`, and `shimmer` support UX and utility flows.

## Platform targets

The repository includes Android, iOS, macOS, Linux, Windows, and web folders generated from Flutter. The active product focus appears to be mobile-first, with Android and iOS flows carrying the core runtime integrations.

## Quality gates

The repository now includes:

- GitHub Actions CI for `flutter analyze` and `flutter test`
- Dependabot updates for `pub` dependencies and GitHub Actions
- Structured issue and pull request templates for clearer maintenance flow

## Recommended next improvements

- Move publishable and environment-specific keys out of source-controlled constants
- Expand widget and service tests around auth, routing, and payment-adjacent flows
- Add release notes per shipped build so recruiters and collaborators can see active maintenance
