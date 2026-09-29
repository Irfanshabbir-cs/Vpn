import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { createApp } from '../src/app.js';

let app;
let server;
let baseUrl;

beforeEach(async () => {
  app = createApp({
    databasePath: ':memory:',
    env: { NODE_ENV: 'test', JWT_SECRET: 'test-secret-with-enough-entropy', CODE_SECRET: 'test-code-secret' },
    testing: true,
    logger: { info() {}, warn() {}, error(error) { throw error; } },
  });
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

afterEach(async () => {
  await new Promise((resolve) => server.close(resolve));
  app.locals.db.close();
});

test('register, verify email, login, and rotate refresh token', async () => {
  const registerResponse = await fetch(`${baseUrl}/v1/auth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'person@example.test', password: 'a-secure-passphrase' }),
  });
  assert.equal(registerResponse.status, 201);
  const registered = await registerResponse.json();
  assert.equal(registered.user.email_verified, false);
  assert.ok(registered.access_token);

  const code = registered.test_code;
  const verifyResponse = await fetch(`${baseUrl}/v1/auth/otp/verify`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'person@example.test', otp: code }),
  });
  assert.equal(verifyResponse.status, 200);

  const loginResponse = await fetch(`${baseUrl}/v1/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'person@example.test', password: 'a-secure-passphrase' }),
  });
  assert.equal(loginResponse.status, 200);
  const login = await loginResponse.json();

  const profileResponse = await fetch(`${baseUrl}/v1/users/me`, {
    headers: { authorization: `Bearer ${login.access_token}` },
  });
  assert.equal(profileResponse.status, 200);
  assert.equal((await profileResponse.json()).email, 'person@example.test');

  const refreshResponse = await fetch(`${baseUrl}/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ refresh_token: login.refresh_token }),
  });
  assert.equal(refreshResponse.status, 200);
  const refreshed = await refreshResponse.json();
  assert.notEqual(refreshed.refresh_token, login.refresh_token);

  const reusedResponse = await fetch(`${baseUrl}/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ refresh_token: login.refresh_token }),
  });
  assert.equal(reusedResponse.status, 401);
});

test('server catalog is empty until an administrator provisions server metadata', async () => {
  const response = await fetch(`${baseUrl}/v1/servers`);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).data, []);
});

test('connection provisioning fails closed when no WireGuard provisioner is configured', async () => {
  const registerResponse = await fetch(`${baseUrl}/v1/auth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'person@example.test', password: 'a-secure-passphrase' }),
  });
  const { access_token: token } = await registerResponse.json();
  const response = await fetch(`${baseUrl}/v1/connections`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ server_id: 'any-server', protocol: 'wireGuard' }),
  });
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, 'provisioner_unavailable');
});