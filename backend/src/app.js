import { randomBytes, randomInt, randomUUID, createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { hash, verify } from '@node-rs/argon2';
import cors from 'cors';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import helmet from 'helmet';
import jwt from 'jsonwebtoken';
import { openDatabase } from './database.js';

const ACCESS_TTL_SECONDS = 15 * 60;
const REFRESH_TTL_DAYS = 30;
const OTP_TTL_MINUTES = 5;

function hashToken(value) {
  return createHash('sha256').update(value).digest('hex');
}

function userDto(row) {
  return {
    id: row.id,
    email: row.email,
    display_name: row.display_name,
    photo_url: row.photo_url,
    email_verified: Boolean(row.email_verified),
    plan: 'free',
    plan_expires_at: null,
  };
}

function serverDto(row) {
  return {
    id: row.id,
    country_code: row.country_code,
    country_name: row.country_name,
    city: row.city,
    latitude: row.latitude,
    longitude: row.longitude,
    latency_ms: row.latency_ms,
    load_percent: Math.min(100, Math.round((row.current_users / row.capacity) * 100)),
    current_users: row.current_users,
    categories: JSON.parse(row.categories),
    is_premium: Boolean(row.is_premium),
  };
}

function fail(res, status, code, message) {
  return res.status(status).json({ error: { code, message } });
}

function validEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
}

function parsePage(query) {
  const page = Math.max(1, Number.parseInt(query.page ?? '1', 10) || 1);
  const pageSize = Math.min(100, Math.max(1, Number.parseInt(query.page_size ?? '20', 10) || 20));
  return { page, pageSize, offset: (page - 1) * pageSize };
}

export function createApp({ databasePath = './data/shieldvpn.sqlite', env = process.env, testing = false, logger = console } = {}) {
  if (!env.JWT_SECRET && env.NODE_ENV === 'production') throw new Error('JWT_SECRET must be configured in production.');
  const jwtSecret = env.JWT_SECRET ?? 'local-development-secret-change-this-before-deployment';
  const codeSecret = env.CODE_SECRET ?? jwtSecret;
  const db = openDatabase(databasePath);
  const app = express();
  app.locals.db = db;

  const allowedOrigins = (env.CORS_ORIGINS ?? '').split(',').map((origin) => origin.trim()).filter(Boolean);
  app.use(helmet());
  app.use(cors({
    origin(origin, callback) {
      const localDevOrigin = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin ?? '');
      callback(null, !origin || allowedOrigins.includes(origin) || (allowedOrigins.length === 0 && localDevOrigin));
    },
  }));
  app.use(express.json({ limit: '128kb' }));
  app.use('/v1/auth', rateLimit({ windowMs: 15 * 60 * 1000, limit: 60, standardHeaders: 'draft-7', legacyHeaders: false }));

  function issueAccessToken(user) {
    return jwt.sign({ role: user.role }, jwtSecret, { subject: user.id, expiresIn: ACCESS_TTL_SECONDS });
  }

  function createSessionTokens(user) {
    const accessToken = issueAccessToken(user);
    const refreshToken = randomBytes(48).toString('base64url');
    db.prepare('INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)')
      .run(randomUUID(), user.id, hashToken(refreshToken), new Date(Date.now() + REFRESH_TTL_DAYS * 86400000).toISOString());
    return { access_token: accessToken, refresh_token: refreshToken };
  }

  function issueEmailCode(user) {
    const code = String(randomInt(100000, 1000000));
    const codeHash = createHmac('sha256', codeSecret).update(code).digest('hex');
    db.prepare(`INSERT INTO verification_codes (id, user_id, code_hash, purpose, expires_at)
      VALUES (?, ?, ?, 'email', ?)`)
      .run(randomUUID(), user.id, codeHash, new Date(Date.now() + OTP_TTL_MINUTES * 60000).toISOString());
    if (env.NODE_ENV === 'production') {
      logger.warn('Email delivery is not configured; OTP was not delivered.');
    } else {
      logger.info(`Development verification code for ${user.email}: ${code}`);
    }
    return code;
  }

  function authenticate(req, res, next) {
    const value = req.get('authorization') ?? '';
    if (!value.startsWith('Bearer ')) return fail(res, 401, 'unauthorized', 'Sign in to continue.');
    try {
      const payload = jwt.verify(value.slice(7), jwtSecret);
      req.user = { id: payload.sub, role: payload.role };
      return next();
    } catch {
      return fail(res, 401, 'unauthorized', 'Your session has expired.');
    }
  }

  function requireAdmin(req, res, next) {
    if (req.user.role !== 'admin') return fail(res, 403, 'forbidden', 'Administrator access is required.');
    return next();
  }

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.post('/v1/auth/register', async (req, res, next) => {
    try {
      const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
      const password = req.body.password;
      if (!validEmail(email) || typeof password !== 'string' || password.length < 8 || password.length > 128) {
        return fail(res, 400, 'invalid_input', 'Enter a valid email and a password of at least 8 characters.');
      }
      if (db.prepare('SELECT 1 FROM users WHERE email = ?').get(email)) {
        return fail(res, 409, 'email_in_use', 'An account with this email already exists.');
      }
      const id = randomUUID();
      const passwordHash = await hash(password);
      db.prepare('INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)').run(id, email, passwordHash);
      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
      const verificationCode = issueEmailCode(user);
      const tokens = createSessionTokens(user);
      return res.status(201).json({ user: userDto(user), ...tokens, ...(testing ? { test_code: verificationCode } : {}) });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/v1/auth/login', async (req, res, next) => {
    try {
      const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
      const password = req.body.password;
      const user = db.prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL').get(email);
      const passwordMatches = user && typeof password === 'string' && await verify(user.password_hash, password);
      if (!passwordMatches) return fail(res, 401, 'invalid_credentials', 'Incorrect email or password.');
      return res.json({ user: userDto(user), ...createSessionTokens(user) });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/v1/auth/google', (_req, res) => fail(res, 501, 'not_configured', 'Google sign-in provider is not configured.'));
  app.post('/v1/auth/apple', (_req, res) => fail(res, 501, 'not_configured', 'Apple sign-in provider is not configured.'));

  app.post('/v1/auth/refresh', (req, res) => {
    const refreshToken = req.body.refresh_token;
    if (typeof refreshToken !== 'string') return fail(res, 400, 'invalid_token', 'A refresh token is required.');
    const tokenHash = hashToken(refreshToken);
    const stored = db.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ? AND revoked_at IS NULL').get(tokenHash);
    if (!stored || Date.parse(stored.expires_at) <= Date.now()) {
      return fail(res, 401, 'invalid_token', 'The refresh token is invalid or expired.');
    }
    const user = db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(stored.user_id);
    if (!user) return fail(res, 401, 'invalid_token', 'The account is unavailable.');
    db.prepare('UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE id = ?').run(stored.id);
    return res.json(createSessionTokens(user));
  });

  app.post('/v1/auth/logout', (req, res) => {
    const token = req.body.refresh_token;
    if (typeof token === 'string') {
      db.prepare('UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE token_hash = ?').run(hashToken(token));
    }
    return res.status(204).end();
  });

  app.post('/v1/auth/otp/send', (req, res) => {
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const user = db.prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL').get(email);
    if (!user) return res.json({ message: 'If the account exists, a code has been sent.' });
    const code = issueEmailCode(user);
    return res.json({ message: 'If the account exists, a code has been sent.', ...(testing ? { test_code: code } : {}) });
  });

  app.post('/v1/auth/otp/verify', (req, res) => {
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const code = req.body.otp;
    if (typeof code !== 'string' || !/^\d{6}$/.test(code)) return fail(res, 400, 'invalid_code', 'Enter the 6-digit code.');
    const row = db.prepare(`SELECT verification_codes.*, users.email FROM verification_codes
      JOIN users ON users.id = verification_codes.user_id
      WHERE users.email = ? AND purpose = 'email' AND used_at IS NULL
      ORDER BY verification_codes.created_at DESC LIMIT 1`).get(email);
    if (!row || Date.parse(row.expires_at) <= Date.now()) return fail(res, 400, 'invalid_code', 'The code is invalid or expired.');
    const submitted = Buffer.from(createHmac('sha256', codeSecret).update(code).digest('hex'));
    const expected = Buffer.from(row.code_hash);
    if (submitted.length !== expected.length || !timingSafeEqual(submitted, expected)) {
      return fail(res, 400, 'invalid_code', 'The code is invalid or expired.');
    }
    db.prepare('UPDATE verification_codes SET used_at = CURRENT_TIMESTAMP WHERE id = ?').run(row.id);
    db.prepare('UPDATE users SET email_verified = 1 WHERE id = ?').run(row.user_id);
    return res.json({ message: 'Email verified.' });
  });

  app.post('/v1/auth/password/forgot', (req, res) => {
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const user = db.prepare('SELECT id FROM users WHERE email = ? AND deleted_at IS NULL').get(email);
    if (user) {
      const token = randomBytes(32).toString('base64url');
      const tokenHash = hashToken(token);
      db.prepare(`INSERT INTO verification_codes (id, user_id, code_hash, purpose, expires_at)
        VALUES (?, ?, ?, 'password_reset', ?)`)
        .run(randomUUID(), user.id, tokenHash, new Date(Date.now() + 30 * 60000).toISOString());
      if (env.NODE_ENV !== 'production') logger.info(`Development password reset token for ${email}: ${token}`);
    }
    return res.json({ message: 'If the account exists, reset instructions have been sent.' });
  });

  app.post('/v1/auth/password/reset', async (req, res, next) => {
    try {
      const { token, new_password: password } = req.body;
      if (typeof token !== 'string' || typeof password !== 'string' || password.length < 8 || password.length > 128) {
        return fail(res, 400, 'invalid_input', 'A valid reset token and password of at least 8 characters are required.');
      }
      const row = db.prepare(`SELECT * FROM verification_codes WHERE code_hash = ? AND purpose = 'password_reset'
        AND used_at IS NULL ORDER BY created_at DESC LIMIT 1`).get(hashToken(token));
      if (!row || Date.parse(row.expires_at) <= Date.now()) return fail(res, 400, 'invalid_token', 'The reset token is invalid or expired.');
      const passwordHash = await hash(password);
      db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, row.user_id);
      db.prepare('UPDATE verification_codes SET used_at = CURRENT_TIMESTAMP WHERE id = ?').run(row.id);
      db.prepare('UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = ? AND revoked_at IS NULL').run(row.user_id);
      return res.json({ message: 'Password updated.' });
    } catch (error) {
      return next(error);
    }
  });

  app.get('/v1/users/me', authenticate, (req, res) => {
    const user = db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(req.user.id);
    if (!user) return fail(res, 404, 'not_found', 'Account not found.');
    return res.json(userDto(user));
  });

  app.patch('/v1/users/me', authenticate, (req, res) => {
    const displayName = req.body.display_name;
    const photoUrl = req.body.photo_url;
    if (displayName !== undefined && (typeof displayName !== 'string' || displayName.length > 100)) {
      return fail(res, 400, 'invalid_input', 'Display name must be 100 characters or fewer.');
    }
    if (photoUrl !== undefined && photoUrl !== null && (typeof photoUrl !== 'string' || photoUrl.length > 2048)) {
      return fail(res, 400, 'invalid_input', 'Photo URL is invalid.');
    }
    db.prepare('UPDATE users SET display_name = COALESCE(?, display_name), photo_url = COALESCE(?, photo_url) WHERE id = ?')
      .run(displayName ?? null, photoUrl ?? null, req.user.id);
    return res.json(userDto(db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id)));
  });

  app.delete('/v1/users/me', authenticate, (req, res) => {
    db.prepare('UPDATE users SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?').run(req.user.id);
    db.prepare('UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = ? AND revoked_at IS NULL').run(req.user.id);
    return res.status(204).end();
  });

  app.get('/v1/users/me/devices', authenticate, (_req, res) => res.json({ data: [], page: 1, page_size: 20, total: 0 }));

  app.get('/v1/servers', (req, res) => {
    const { page, pageSize, offset } = parsePage(req.query);
    const conditions = ['is_active = 1'];
    const parameters = [];
    if (typeof req.query.country === 'string') {
      conditions.push('country_code = ?');
      parameters.push(req.query.country.toUpperCase());
    }
    if (typeof req.query.category === 'string') {
      conditions.push('EXISTS (SELECT 1 FROM json_each(servers.categories) WHERE value = ?)');
      parameters.push(req.query.category);
    }
    const where = conditions.join(' AND ');
    const sort = req.query.sort === 'load' ? '(current_users * 1.0 / capacity) ASC' : 'latency_ms ASC, (current_users * 1.0 / capacity) ASC';
    const total = db.prepare(`SELECT COUNT(*) AS count FROM servers WHERE ${where}`).get(...parameters).count;
    const rows = db.prepare(`SELECT * FROM servers WHERE ${where} ORDER BY ${sort} LIMIT ? OFFSET ?`)
      .all(...parameters, pageSize, offset);
    return res.json({ data: rows.map(serverDto), page, page_size: pageSize, total });
  });

  app.get('/v1/servers/recommended', (_req, res) => {
    const row = db.prepare('SELECT * FROM servers WHERE is_active = 1 ORDER BY (current_users * 1.0 / capacity) ASC LIMIT 1').get();
    if (!row) return fail(res, 404, 'no_servers', 'No active VPN servers are configured.');
    return res.json(serverDto(row));
  });

  app.get('/v1/servers/:id', (req, res) => {
    const row = db.prepare('SELECT * FROM servers WHERE id = ? AND is_active = 1').get(req.params.id);
    if (!row) return fail(res, 404, 'not_found', 'Server not found.');
    return res.json(serverDto(row));
  });

  app.post('/v1/admin/servers', authenticate, requireAdmin, (req, res) => {
    const { country_code: countryCode, country_name: countryName, city, hostname } = req.body;
    if (typeof countryCode !== 'string' || !/^[A-Za-z]{2}$/.test(countryCode) ||
        typeof countryName !== 'string' || !countryName.trim() || typeof city !== 'string' || !city.trim() ||
        typeof hostname !== 'string' || !/^[a-zA-Z0-9.-]+$/.test(hostname)) {
      return fail(res, 400, 'invalid_input', 'Country code, country name, city, and hostname are required.');
    }
    const categories = Array.isArray(req.body.categories) && req.body.categories.every((item) => typeof item === 'string')
      ? [...new Set(req.body.categories)] : ['standard'];
    const id = randomUUID();
    db.prepare(`INSERT INTO servers (id, country_code, country_name, city, hostname, latitude, longitude,
      latency_ms, capacity, current_users, categories, is_premium, is_active)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(id, countryCode.toUpperCase(), countryName.trim(), city.trim(), hostname,
        Number.isFinite(req.body.latitude) ? req.body.latitude : null,
        Number.isFinite(req.body.longitude) ? req.body.longitude : null,
        Number.isInteger(req.body.latency_ms) && req.body.latency_ms > 0 ? req.body.latency_ms : 0,
        Number.isInteger(req.body.capacity) && req.body.capacity > 0 ? req.body.capacity : 1,
        Number.isInteger(req.body.current_users) && req.body.current_users >= 0 ? req.body.current_users : 0,
        JSON.stringify(categories), Boolean(req.body.is_premium) ? 1 : 0, 1);
    return res.status(201).json(serverDto(db.prepare('SELECT * FROM servers WHERE id = ?').get(id)));
  });

  app.delete('/v1/admin/servers/:id', authenticate, requireAdmin, (req, res) => {
    const result = db.prepare('UPDATE servers SET is_active = 0 WHERE id = ?').run(req.params.id);
    if (!result.changes) return fail(res, 404, 'not_found', 'Server not found.');
    return res.status(204).end();
  });

  app.post('/v1/connections', authenticate, (_req, res) => fail(
    res,
    503,
    'provisioner_unavailable',
    'VPN config provisioning is not configured. Add a WireGuard peer provisioner before connecting.',
  ));

  app.patch('/v1/connections/:sessionId', authenticate, (req, res) => {
    const result = db.prepare(`UPDATE sessions SET bytes_in = ?, bytes_out = ? WHERE id = ? AND user_id = ? AND ended_at IS NULL`)
      .run(Math.max(0, Number(req.body.bytes_in) || 0), Math.max(0, Number(req.body.bytes_out) || 0), req.params.sessionId, req.user.id);
    if (!result.changes) return fail(res, 404, 'not_found', 'Active session not found.');
    return res.json({ message: 'Session updated.' });
  });

  app.delete('/v1/connections/:sessionId', authenticate, (req, res) => {
    db.prepare('UPDATE sessions SET ended_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ? AND ended_at IS NULL')
      .run(req.params.sessionId, req.user.id);
    return res.status(204).end();
  });

  app.get('/v1/connections/history', authenticate, (req, res) => {
    const { page, pageSize, offset } = parsePage(req.query);
    const total = db.prepare('SELECT COUNT(*) AS count FROM sessions WHERE user_id = ?').get(req.user.id).count;
    const rows = db.prepare(`SELECT sessions.*, servers.city, servers.country_code FROM sessions
      JOIN servers ON servers.id = sessions.server_id WHERE user_id = ? ORDER BY started_at DESC LIMIT ? OFFSET ?`)
      .all(req.user.id, pageSize, offset);
    return res.json({ data: rows, page, page_size: pageSize, total });
  });

  app.use((error, _req, res, _next) => {
    logger.error(error);
    if (res.headersSent) return;
    return fail(res, 500, 'internal_error', 'An unexpected server error occurred.');
  });

  return app;
}

export function createBootstrapAdmin(db, email, password) {
  if (!email || !password) throw new Error('Provide admin email and password.');
  if (password.length < 12) throw new Error('Admin password must be at least 12 characters.');
  return hash(password).then((passwordHash) => {
    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase());
    if (existing) throw new Error('That account already exists.');
    const id = randomUUID();
    db.prepare(`INSERT INTO users (id, email, password_hash, email_verified, role)
      VALUES (?, ?, ?, 1, 'admin')`).run(id, email.toLowerCase(), passwordHash);
    return id;
  });
}

export function codeDigest(code, secret) {
  return createHmac('sha256', secret).update(code).digest('hex');
}