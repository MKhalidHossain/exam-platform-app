# EJ Flutter App

EJ Flutter App is the mobile codebase behind an inspector exam preparation experience that combines authentication, exam unlocks, paid resources, quiz sessions, performance tracking, referrals, and profile management in a single Flutter application.

It uses a controller-driven structure with `GetX` for state management, `GoRouter` for navigation, `http` for API access, local persistence for session data, deep links for shared content, and Stripe for purchase flows.

---

## Preview

<p align="center">
  A compact product flow showing home, unlock, resources, exam practice, results, and profile management.
</p>

<table>
  <tr>
    <td align="center"><img src="docs/screenshorts/13-home-screen-professional-plan.png" alt="Home Screen Professional Plan" width="220"><br><strong>Home</strong></td>
    <td align="center"><img src="docs/screenshorts/14-unlock-exam-selection-dialog.png" alt="Unlock Exam Selection Dialog" width="220"><br><strong>Exam Unlock</strong></td>
    <td align="center"><img src="docs/screenshorts/15-add-on-resource-checkout-dialog.png" alt="Add-on Resource Checkout Dialog" width="220"><br><strong>Checkout Add-on</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshorts/01-resources-tab-overview.png" alt="Resources Tab Overview" width="220"><br><strong>Resources</strong></td>
    <td align="center"><img src="docs/screenshorts/02-api510-resource-category-list.png" alt="API 510 Resource Category List" width="220"><br><strong>Category List</strong></td>
    <td align="center"><img src="docs/screenshorts/03-api510-resource-details-unlocked.png" alt="API 510 Resource Details Unlocked" width="220"><br><strong>Resource Details</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshorts/05-api510-resource-details-payment.png" alt="API 510 Resource Details Payment" width="220"><br><strong>Resource Payment</strong></td>
    <td align="center"><img src="docs/screenshorts/08-exam-session-question-1.png" alt="Exam Session Question 1" width="220"><br><strong>Exam Session</strong></td>
    <td align="center"><img src="docs/screenshorts/10-exam-review-screen.png" alt="Exam Review Screen" width="220"><br><strong>Exam Review</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshorts/11-quiz-complete-results.png" alt="Quiz Complete Results" width="220"><br><strong>Results</strong></td>
    <td align="center"><img src="docs/screenshorts/12-performance-dashboard.png" alt="Performance Dashboard" width="220"><br><strong>Performance</strong></td>
    <td align="center"><img src="docs/screenshorts/16-profile-screen.png" alt="Profile Screen" width="220"><br><strong>Profile</strong></td>
  </tr>
</table>

---

## Download APK

<p align="center">
  <strong>Get the latest Android build</strong><br>
  <a href="https://drive.google.com/file/d/1JJsvq3pIk6L81fwBCSxZxe-3rcVtQfut/view?usp=sharing">Download Android APK</a>
</p>

> Recommended next step after previewing the product flow.
> Open the APK link to install and test the latest mobile build.

---

## Highlights

- Authentication, onboarding, OTP verification, password reset, and remember-me login
- Exam selection, unlock flows, subscription upsell, and Stripe-based payment handling
- Resource browsing with category pages, detail pages, and PDF-based content delivery
- Quiz sessions, review flow, score summary, and performance tracking
- Referral and shared-link flows through app links
- Persistent local session and installation identity handling

## Tech Stack

- Flutter and Dart
- `GetX` for app state and controllers
- `GoRouter` for route handling
- `http` for API requests
- `shared_preferences` and `flutter_secure_storage` for persistence
- `flutter_stripe` for checkout flows
- `app_links` for deep-link handling
- `syncfusion_flutter_pdfviewer` for in-app PDF viewing

## Project Structure

```text
lib/
├── controllers/   # GetX controllers and app state orchestration
├── models/        # API models and domain entities
├── routes/        # GoRouter route definitions
├── services/      # API, auth, storage, referral, ebook, and exam services
├── utils/         # Constants, theme, colors, navigation helpers
└── views/         # Screens and reusable UI widgets
```

## Main Flows

- Auth: splash, onboarding, login, sign up, forgot password, OTP, reset password
- Practice: home, quiz settings, exam session, review, results, performance
- Resources: resource tab, category list, detail page, PDF viewer, purchase path
- Account: profile, edit profile, change password, subscription, referral

## Getting Started

### Requirements

- Flutter SDK
- Dart SDK
- Android Studio or VS Code with Flutter tooling
- Android emulator, iOS simulator, or a physical device

### Install

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Build

```bash
flutter build apk --release
flutter build ios --release
```

## Configuration

Update the main runtime constants in [lib/utils/app_constants.dart](/Users/saa/dev/flutter/ej7696_flutter_jakir/lib/utils/app_constants.dart:1).

Important values:

- `AppConstants.apiOrigin`
- `AppConstants.baseUrl`
- `AppConstants.publicBaseUrl`
- `AppConstants.appLinkScheme`
- `AppConstants.stripePublishableKey`

Theme and styling live in:

- [lib/utils/app_theme.dart](/Users/saa/dev/flutter/ej7696_flutter_jakir/lib/utils/app_theme.dart:1)
- [lib/utils/app_colors.dart](/Users/saa/dev/flutter/ej7696_flutter_jakir/lib/utils/app_colors.dart:1)

## Notes

- The screenshot assets in this README currently live under `docs/screenshorts/`.
- The project uses `GetX`, not Riverpod.
- The Stripe publishable key is currently defined in source; for production, it should move to a safer environment-based configuration.
