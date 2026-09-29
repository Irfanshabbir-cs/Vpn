# Architecture

## Layers

```
lib/
  core/                 # cross-cutting: theme, router, constants, utils
  data/
    models/             # plain Dart data classes (fromJson/toJson)
    repositories/       # interfaces + implementations (Mock* now, Remote* later)
  presentation/
    providers/          # Riverpod StateNotifiers / Providers (the "ViewModel" layer)
    screens/             # one folder per screen, widgets/ subfolder for screen-local pieces
    widgets/common/       # shared, reusable widgets
```

This follows Clean Architecture with an MVVM-flavored presentation layer:

- **Model** — `data/models`
- **View** — `presentation/screens/**`
- **ViewModel** — `presentation/providers/**` (Riverpod `StateNotifier`s expose immutable state; widgets never mutate state directly)
- **Repository** — `data/repositories/**` is the seam between the app and the outside world (REST API, Firebase, platform VPN channel). Every repository is an abstract class with a `Mock*` implementation so the UI is fully runnable before the backend exists, and a `Remote*` implementation slots in later without touching a single screen.

## Why mocks first

Every repository (`AuthRepository`, `ServerRepository`, `VpnRepository`) is an interface. Authentication still uses `MockAuthRepository`. Android VPN connections use `WireGuardVpnRepository`; profiles are imported from `.conf` files and stored through `flutter_secure_storage`. The server catalog remains mock data until a backend is connected, but those demo entries cannot be used to connect.

1. Implement `RemoteAuthRepository` using `Dio` + Firebase Auth, matching the endpoints in `BACKEND_GUIDE.md`.
2. Implement `RemoteServerRepository` calling `GET /servers`.
3. Add iOS Network Extension and Windows tunnel implementations behind the same `VpnRepository` interface.
4. Connect `ServerRepository` to the backend's real server/profile API.

## State management (Riverpod)

- `authProvider` — `StateNotifierProvider<AuthNotifier, AuthState>`, drives GoRouter's `redirect`.
- `serversProvider` / `filteredServersProvider` — server list + derived search/filter/sort.
- `vpnConnectionStateProvider` — `StreamProvider` wrapping native WireGuard tunnel state on Android.
- `connectionStatsProvider` — exposes duration; IP, ping, and throughput remain unavailable until measured from real sources.

## Navigation (GoRouter)

`core/router/app_router.dart` centralizes all routes and an auth guard (`redirect`) that:
- Sends unauthenticated users to `/login` from any protected route.
- Sends authenticated users away from auth/onboarding routes to `/home`.
- Leaves `/` (splash) alone so it can run its own bootstrap sequence (session restore, onboarding-seen check) before the first `context.go`.

## What's built in this pass

Splash → Onboarding (4 pages) → Login / Register / Forgot Password / OTP → Home (connect button, live status card, server picker entry point) → Server List (search, category filter, sort, favorites, recents).

## What's next (not yet built)

Map view, Speed Test, Settings, Account/Subscription, Admin panel, and the native VPN tunnel integration. These follow the exact same repository-interface + Riverpod-provider + screen pattern established here — see `server_list_screen.dart` as the template for any new list-based screen, and `home_screen.dart` for any new stream-driven screen.
