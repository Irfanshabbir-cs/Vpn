# ShieldVPN

ShieldVPN is a Flutter-based VPN client prototype focused on secure access, modern mobile UI, and a clean architecture for future production integration.

This project demonstrates a full-stack product direction: a mobile-first VPN experience, role-aware authentication flows, and a backend contract designed for secure connectivity and profile management.

## Overview

ShieldVPN includes:

- Material 3-based UI with light/dark theme support
- Authentication screens for login, registration, password reset, and OTP flows
- Guided onboarding experience for app setup and trust-building
- Home dashboard with connection status and server selection
- Server catalog with search, sorting, and filtering
- Android WireGuard support for importing and connecting via .conf profiles
- A clean, repository-based architecture designed for future backend and real VPN infrastructure integration

## Tech Stack

| Layer | Technology |
| --- | --- |
| Mobile App | Flutter, Dart |
| State Management | Riverpod |
| Navigation | GoRouter |
| UI | Material 3 |
| VPN Integration | WireGuard for Android |
| Backend Contract | Node.js + SQLite API design |
| Security | Secure storage, JWT-based auth model |

## Current Status

This repo is a polished MVP/client foundation rather than a production-ready VPN service.

### Included

- App shell and core navigation
- Onboarding and auth experiences
- Server listing and filtering
- Android VPN profile import flow
- Clean repository and provider architecture

### Planned / Not Yet Implemented

- Full production backend deployment
- Real server provisioning and live tunnel management
- iOS and Windows tunnel support
- Payments and subscriptions
- Push notifications
- Real analytics and crash reporting
- CI/CD pipeline and production hardening

## Project Structure

```text
.
├── android/
├── assets/
├── backend/
├── docs/
├── lib/
├── test/
├── web/
├── .gitignore
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
├── README.md
└── LICENSE
```

## Local Development

### Prerequisites

- Flutter 3.22+
- Dart 3.3+
- Android Studio for Android testing

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

For web preview:

```bash
flutter run -d chrome
```

## Local Backend

The backend folder includes a local Node.js API for testing auth and server metadata flows.

```powershell
cd backend
npm install
$env:JWT_SECRET = 'replace-with-a-long-random-secret'
$env:CODE_SECRET = 'replace-with-another-long-random-secret'
npm start
```

The local API runs on:

- http://localhost:8080

Then run the app with the backend URL defined:

```powershell
flutter run -d chrome --dart-define=BASE_API_URL=http://localhost:8080/v1
```

## Android WireGuard

For Android device testing:

1. Install Android Studio and the Android SDK.
2. Connect a device or start an emulator.
3. Open the app and import a valid WireGuard .conf profile.
4. Grant Android VPN permissions when prompted.

The tunnel requires a valid profile and a reachable WireGuard server. Without real infrastructure, this remains a UI-ready and local-demo flow rather than a live production connection.

## Architecture Notes

The application follows a clean architecture approach with clear separation between:

- domain/data repositories
- state providers
- navigation logic
- screen UI

For details, see:

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/BACKEND_GUIDE.md](docs/BACKEND_GUIDE.md)

## Security and Production Notes

This repo is intentionally built to show architecture and UX patterns, not to be a production VPN service yet.

Important considerations for production include:

- HTTPS everywhere
- secure secret management
- real email verification and OTP delivery
- trusted backend and identity providers
- explicit CORS configuration
- secure WireGuard provisioning and tunnel lifecycle handling

## Roadmap

- Real backend integration
- Secure profile provisioning
- iOS and Windows support
- Payment and user account flows
- Monitoring and analytics
- CI/CD and release automation

## License

This project is licensed under the MIT License.
