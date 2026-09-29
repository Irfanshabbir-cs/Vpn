# Backend Guide

No server exists yet. This document is the contract the Flutter client already codes against
(see `data/repositories/*`), so a backend built to this spec is a drop-in replacement for the
mock repositories.

Suggested stack: Node.js (NestJS) or Go, PostgreSQL, Redis (rate limiting/session cache),
S3-compatible storage for invoices/exports. Any stack works as long as the API contract holds.

## Auth model

- JWT access token (short-lived, ~15 min) + refresh token (long-lived, rotated on use, stored
  server-side to allow revocation).
- Client stores tokens in `flutter_secure_storage`, never Hive/SharedPreferences.
- Dio interceptor attaches `Authorization: Bearer <access>` and retries once on 401 after a
  refresh call.

## REST API

Base path: `/v1`. All request/response bodies are JSON. All list endpoints are paginated with
`?page=&page_size=` and return `{ data: [...], page, page_size, total }`.

### Authentication
| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register` | email, password → creates unverified user, sends OTP email |
| POST | `/auth/login` | email, password → access + refresh tokens |
| POST | `/auth/google` | id_token from Google Sign-In → tokens |
| POST | `/auth/apple` | identity_token from Sign in with Apple → tokens |
| POST | `/auth/refresh` | refresh_token → new access + refresh tokens (rotated) |
| POST | `/auth/logout` | revokes refresh_token |
| POST | `/auth/otp/send` | email → sends 6-digit OTP, 5 min TTL |
| POST | `/auth/otp/verify` | email, otp → marks email verified |
| POST | `/auth/password/forgot` | email → sends reset link |
| POST | `/auth/password/reset` | token, new_password |

### Users
| Method | Path | Notes |
|---|---|---|
| GET | `/users/me` | current profile + subscription summary |
| PATCH | `/users/me` | update display_name, photo_url |
| DELETE | `/users/me` | account deletion (soft-delete + 30-day purge job) |
| GET | `/users/me/devices` | linked devices for multi-device plans |
| DELETE | `/users/me/devices/:id` | revoke a device |

### Servers
| Method | Path | Notes |
|---|---|---|
| GET | `/servers` | filter by `country`, `category`, `sort=fastest\|load` |
| GET | `/servers/:id` | single server detail |
| GET | `/servers/recommended` | AI/heuristic "smart connect" pick for the requesting IP |

### Connection (VPN session bookkeeping — the tunnel itself is client-native)
| Method | Path | Notes |
|---|---|---|
| POST | `/connections` | server_id, protocol → issues WireGuard/OpenVPN config + session_id |
| PATCH | `/connections/:session_id` | heartbeat / stats upload (bytes in/out) |
| DELETE | `/connections/:session_id` | closes session, used for usage accounting |
| GET | `/connections/history` | recent sessions for the "Connection History" screen |

### Subscriptions & payments
| Method | Path | Notes |
|---|---|---|
| GET | `/subscriptions/plans` | plan catalog (free/monthly/yearly/lifetime) with pricing |
| POST | `/subscriptions/verify-purchase` | platform (`google_play`\|`app_store`), purchase_token → activates plan |
| POST | `/subscriptions/promo-code` | code → applies discount/trial |
| GET | `/payments/history` | invoices/payment history |

### Settings & notifications
| Method | Path | Notes |
|---|---|---|
| GET/PATCH | `/settings` | protocol default, DNS, auto-connect rules, kill switch, notifications |
| POST | `/notifications/register-token` | FCM token registration |
| GET | `/notifications` | in-app notification feed (expiry, offers, maintenance) |

### Admin (separate, role-gated base path `/admin/v1`)
`/admin/servers`, `/admin/announcements`, `/admin/feature-flags`, `/admin/maintenance-mode`,
`/admin/remote-config` — standard CRUD, protected by an `admin` role claim in the JWT.

## PostgreSQL schema (core tables)

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT,               -- null for social-only accounts
  display_name TEXT,
  photo_url TEXT,
  email_verified BOOLEAN DEFAULT FALSE,
  auth_provider TEXT NOT NULL DEFAULT 'password', -- password | google | apple
  role TEXT NOT NULL DEFAULT 'user',              -- user | admin
  created_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  device_name TEXT,
  platform TEXT,                    -- ios | android
  push_token TEXT,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE countries (
  code CHAR(2) PRIMARY KEY,         -- ISO 3166-1 alpha-2
  name TEXT NOT NULL
);

CREATE TABLE servers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code CHAR(2) REFERENCES countries(code),
  city TEXT NOT NULL,
  hostname TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  capacity INT NOT NULL,
  current_users INT DEFAULT 0,
  categories TEXT[] DEFAULT '{}',   -- standard, streaming, gaming, p2p, obfuscated, double_vpn
  is_premium BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL,               -- free | premium_monthly | premium_yearly | lifetime
  status TEXT NOT NULL,             -- active | canceled | expired | trial
  platform TEXT,                    -- google_play | app_store | web
  purchase_token TEXT,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id),
  amount_cents INT NOT NULL,
  currency CHAR(3) NOT NULL,
  status TEXT NOT NULL,             -- succeeded | failed | refunded
  invoice_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE sessions (               -- VPN connection sessions (for stats + history)
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES servers(id),
  protocol TEXT NOT NULL,
  bytes_in BIGINT DEFAULT 0,
  bytes_out BIGINT DEFAULT 0,
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  revoked BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_servers_country ON servers(country_code);
CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
```

## Security notes for whoever builds this

- Hash passwords with argon2id, never store plaintext or reversible-encrypted passwords.
- Rate-limit `/auth/*` per IP and per email (Redis token bucket) to blunt credential stuffing.
- Validate all input server-side (this doc's client is not a trust boundary).
- Use parameterized queries / an ORM — never string-concatenate SQL.
- Certificate pin the mobile app against your API's leaf or intermediate cert.
- Keep a strict no-logs policy for actual VPN traffic; the `sessions` table above stores
  connection *metadata* (bytes, timestamps) for billing/UX only, not traffic contents or
  destination IPs, if a genuine no-logs claim is intended.
