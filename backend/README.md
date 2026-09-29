# ShieldVPN API

Local development API for the Flutter client. Requires Node.js 24 or newer; persistence uses the
Node built-in SQLite module, so PostgreSQL and Docker are not required for local development.

## Run locally

```powershell
npm install
$env:JWT_SECRET = 'replace-with-a-long-random-secret'
$env:CODE_SECRET = 'replace-with-another-long-random-secret'
npm start
```

The API listens on `http://localhost:8080`. The SQLite database is created at
`backend/data/shieldvpn.sqlite`. Use `npm test` to run the API tests.

For the Flutter browser client, start it from the project root:

```powershell
flutter run -d chrome --dart-define=BASE_API_URL=http://localhost:8080/v1
```

In development, email-verification OTPs and password-reset tokens are written to the API terminal.
Do not expose this behavior on a public deployment. Production needs a mail provider, HTTPS, strong
secret values supplied outside source control, and explicit `CORS_ORIGINS`.

## Administrator

Create an administrator from a terminal in `backend/`:

```powershell
npm run admin:create -- admin@example.com 'use-a-long-unique-password'
```

Sign in through the API to receive a JWT, then create server metadata with `POST /v1/admin/servers`.
The built-in API does not generate WireGuard keys or configs. `POST /v1/connections` deliberately
returns `503 provisioner_unavailable` until a real, secure WireGuard peer provisioner and VPN server
infrastructure are configured. Never store a shared server private key in the client or issue the
same peer credentials to multiple users.

## Current API scope

- Registration, password login, JWT access tokens, rotating opaque refresh tokens, logout.
- Development OTP and password reset flows (email delivery is not configured).
- Profile read/update/deletion.
- Paginated/filterable server catalog and protected server metadata create/deactivate endpoints.
- Protected connection-history endpoint and fail-closed tunnel-provisioning endpoint.
- Google/Apple login, devices, payments, push messaging, production email, and the actual VPN
  provisioning service still require provider/infrastructure integrations.