# ShieldVPN — Flutter Client (Build Pass 1)

VPN client built with Flutter, Riverpod, GoRouter, and Material 3. Android supports importing
WireGuard profiles and establishing a native tunnel. Authentication is still mock-backed.

## What's included in this pass

- **Core**: theme (light/dark, Material 3, glass helper), GoRouter with an auth-aware redirect guard, app-wide constants.
- **Auth**: Login, Register, Forgot Password, OTP screens; `AuthRepository` interface + `MockAuthRepository`; Google/Apple sign-in buttons wired to stub flows.
- **Onboarding**: 4-page animated onboarding (Fast VPN / Secure Browsing / Global Servers / Privacy Protection).
- **Home**: large animated connect button, live status card (IP, ping, upload/download, duration, protocol), server picker entry point.
- **Servers**: searchable, filterable (streaming/gaming/P2P/etc.), sortable (fastest/lowest load/A–Z) server list with favorites and recents, shimmer loading state.
- **VPN state**: Android WireGuard tunnel via `wireguard_flutter`; imported `.conf` profiles are stored with `flutter_secure_storage`. Browser builds are UI-only. IP, ping, and throughput are not fabricated and remain unavailable until real measurements are implemented.

Not yet built (next passes): iOS and Windows tunnel integrations, backend server catalog,
Map view, Speed Test, Settings, Account/Subscription, Admin panel, push notifications,
biometric login, localization, CI/CD. See `docs/ARCHITECTURE.md`.

## Getting started

> This project was authored as source files; it hasn't been run through `flutter create` /
> `flutter pub get` in this environment (no Flutter SDK / pub.dev access here). Do this locally:

```bash
flutter --version        # Flutter 3.22+ / Dart 3.3+
cd vpn_app
flutter pub get
flutter run
```

## Local backend

The `backend/` directory contains a local Node.js 24 + SQLite API. Start it in one terminal:

```powershell
cd backend
npm install
$env:JWT_SECRET = 'replace-with-a-long-random-secret'
$env:CODE_SECRET = 'replace-with-another-long-random-secret'
npm start
```

The API listens on `http://localhost:8080`. Start the Flutter web app in another terminal from
the project root:

```powershell
flutter run -d chrome --dart-define=BASE_API_URL=http://localhost:8080/v1
```

Registration, password login, OTP verification, account profile, refresh-token rotation, and the
server catalog use the local API. In development, OTP codes and password-reset tokens are printed
to the backend terminal because no email provider is configured. This is for local testing only;
production requires HTTPS, strong secrets, a real email delivery provider, and explicit CORS origins.

The server catalog starts empty. Create a bootstrap administrator, sign in, and use the protected
`POST /v1/admin/servers` endpoint to add real server metadata. Server metadata alone cannot create
a tunnel: `/v1/connections` remains unavailable until a secure WireGuard peer/config provisioner
is implemented and real VPN server infrastructure is configured. Google/Apple login, payments,
and push notifications also require their external providers.

Generate the Android and web platform folders in this directory if they are missing:

```bash
flutter create --project-name vpn_app --org com.yourcompany .
```
(This won't overwrite `lib/`, `pubspec.yaml`, or `docs/`.)

## Android WireGuard

Install Android Studio and its Android SDK, then connect an Android device with USB debugging
enabled or start an emulator. In the app, open **Servers**, tap the import icon, and choose a
WireGuard `.conf` file. The profile must include an `[Interface]` private key and address plus a
`[Peer]` public key, allowed IPs, and endpoint. Profile secrets are stored in Android secure
storage. On first connect, approve Android's VPN permission dialog.

The server list contains imported profiles only; the previous mock server catalog is not used for
connections. The tunnel cannot be tested without a valid profile and reachable WireGuard server.
The web build remains a UI demo because browsers cannot create a device VPN tunnel.

## Firebase setup (optional for this pass)

Firebase Auth/Messaging/Analytics/Crashlytics are in `pubspec.yaml` but initialization in
`main.dart` is commented out, since auth currently runs on `MockAuthRepository`. To wire up
real Firebase:

1. `flutterfire configure` to generate `lib/firebase_options.dart`.
2. Uncomment the `Firebase.initializeApp(...)` block in `main.dart`.
3. Implement `RemoteAuthRepository` using `firebase_auth` + your backend's `/auth/*` endpoints
   (see `docs/BACKEND_GUIDE.md`), and swap it in via `authRepositoryProvider`.

## Backend

No server exists yet. `docs/BACKEND_GUIDE.md` specifies the full REST API contract and
PostgreSQL schema the client already codes against, so a backend built to spec is a drop-in
replacement for the mock repositories — no client code changes beyond swapping `Provider`
overrides.

## Project structure

See `docs/ARCHITECTURE.md` for the full layer breakdown and the pattern to follow when adding
new screens/features.
