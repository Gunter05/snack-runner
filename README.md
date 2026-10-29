# SnackRunner

A Flutter-based delivery and task management application that connects delivery runners with customers for quick pickup and delivery services.

## Project Overview

SnackRunner is a mobile application designed to manage delivery jobs and track their status. Users can request deliveries, accept delivery jobs, and monitor their completion in real-time.

## Features

### Core Functionality
- **User Authentication** - Secure login system for runners and requesters
- **Course Management** - Create, browse, and manage delivery tasks
- **Real-time Tracking** - Monitor delivery progress and status
- **Task Status Tracking** - Track deliveries through multiple states (Pending, Accepted, In Delivery, Completed)
- **Reward System** - Incentivize completed deliveries with rewards

### Screens

| Screen | Purpose |
|--------|---------|
| `LoginScreen` | User authentication |
| `DashboardScreen` | Main application hub |
| `CoursesScreen` | Browse available delivery tasks |
| `CourseDetailScreen` | View detailed information about a specific delivery |
| `NouvelleCourseScreen` | Create a new delivery request |
| `InscriptionScreen` | User registration/enrollment |
| `MissionScreen` | View assigned missions/tasks |
| `FinMissionScreen` | Complete and finalize a delivery |
| `SuiviScreen` | Track delivery progress |
| `RecapitulatifScreen` | Summary and recap of activities |

## Technical Stack

- **Framework**: Flutter 3.9.0+
- **Language**: Dart
- **UI**: Material Design 3
- **Theme**: Custom green theme (Primary color: #1A6B4A)

## Project Structure

```
lib/
├── main.dart                 # Entry point (Supabase, FCM, router)
├── core/                     # Config, validators, error messages
├── models/                   # Course (errands table), UserProfile
├── repositories/             # Supabase access (auth, errands, reviews)
├── providers/                # Riverpod providers (session, courses)
├── router/app_router.dart    # go_router routes + auth redirect
├── services/                 # Push notifications (FCM)
├── screens/                  # UI screens
└── widgets/                  # Shared widgets
supabase/
├── migrations/               # SQL migrations (RLS, triggers)
└── functions/                # Edge Functions (push notifications)
```

## Delivery Status States

Mapped to the Postgres enum `errand_status`:

- **En attente** (`waiting`) - published, waiting for a runner; the requester can cancel
- **Acceptée** (`accepted`) - a runner accepted it (one active mission per runner)
- **Livraison** (`delivering`) - delivery in progress
- **Terminée** (`done`) - delivered; both participants can rate each other
- **Annulée** (`cancelled`) - cancelled by the requester

## Getting Started

### Prerequisites
- Flutter SDK 3.9.0 or higher
- Android SDK or iOS development tools

### Configuration

The Supabase URL and anon key are injected at build time (they are no longer
bundled as a readable `.env` asset):

```bash
cp .env.example .env   # then fill in SUPABASE_ANON_KEY
```

Run or build with:

```bash
flutter run --dart-define-from-file=.env
```

```bash
flutter build appbundle --release --dart-define-from-file=.env
```

Without these values the app shows a configuration error screen.

### Web (production target)

The web app is deployed on Vercel by GitHub Actions (`.github/workflows/web.yml`):
preview URL for each pull request, production for `main`. Setup steps
(Vercel project, GitHub secrets, Supabase Auth URLs and SMTP) are in
[docs/deploiement-web.md](docs/deploiement-web.md).

Local web run:

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Push notifications are not enabled on the web yet.

### Push notifications

- Android: `android/app/google-services.json` (Firebase project).
- iOS: add `ios/Runner/GoogleService-Info.plist` and enable the Push
  Notifications capability in Xcode. Without it the app runs without push.
- Edge Function secrets: `WEBHOOK_SECRET`, `CRON_SECRET`, `FCM_PROJECT_ID`,
  `FCM_SERVICE_ACCOUNT_JSON`, plus the `webhook_secret` Vault entry (see
  `supabase/migrations/20261028230000_security_hardening_2.sql`).

### Android release signing

Create `android/key.properties` (not committed):

```
storeFile=/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without this file, release builds are signed with the debug key and cannot be
published on the Play Store.

### Tests

```bash
flutter analyze
```

```bash
flutter test
```

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)
- [Material Design 3](https://m3.material.io/)
