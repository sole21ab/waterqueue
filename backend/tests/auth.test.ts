import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import Fastify from 'fastify';
import bcrypt from 'bcryptjs';
import jwt from '@fastify/jwt';

const { mockUserFindUnique, mockUserCreate, mockDisconnect } = vi.hoisted(() => ({
  mockUserFindUnique: vi.fn(),
  mockUserCreate: vi.fn(),
  mockDisconnect: vi.fn(),
}));

vi.mock('../src/prisma/client.js', () => ({
  prisma: {
    user: {
      findUnique: mockUserFindUnique,
      create: mockUserCreate,
    },
    $disconnect: mockDisconnect,
  },
}));

import authRoutes from '../src/routes/auth.js';
import { authenticate, requireAdmin } from '../src/middleware/auth.js';

const TEST_EMAIL = 'resident@example.com';
const TEST_PASSWORD = 'StrongPass123456';
const TEST_USER_ID = 'aaaaaaaa-bbbb-cccc-dddd-000000000001';

const buildApp = async () => {
  const app = Fastify({ logger: false });
  await app.register(jwt, {
    secret: process.env.JWT_SECRET || 'test-secret-key-that-is-at-least-32-chars-long',
    sign: { expiresIn: '24h' },
  });
  app.register(authRoutes);

  // Protected routes used to test the authentication middleware.
  app.get('/protected', { preHandler: [authenticate] }, async (request, reply) => {
    const payload = request.user as { sub?: string };
    return reply.send({ ok: true, sub: payload.sub });
  });

  app.get(
    '/admin-only',
    { preHandler: [authenticate, requireAdmin] },
    async (_request, reply) => {
      return reply.send({ ok: true });
    }
  );

  await app.ready();
  return app;
};

describe('POST /auth/register', () => {
  let app: Awaited<ReturnType<typeof buildApp>>;

  beforeAll(async () => {
    app = await buildApp();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns 201 with a token and safe user info when registration succeeds', async () => {
    mockUserFindUnique.mockResolvedValue(null);
    mockUserCreate.mockResolvedValue({
      id: TEST_USER_ID,
      email: TEST_EMAIL,
      role: 'resident',
      createdAt: new Date('2024-01-01T00:00:00Z'),
    });

    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: { email: TEST_EMAIL, password: TEST_PASSWORD },
    });

    expect(response.statusCode).toBe(201);

    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('token');
    expect(typeof body.token).toBe('string');
    expect(body.user.id).toBe(TEST_USER_ID);
    expect(body.user.email).toBe(TEST_EMAIL);
    expect(body.user.role).toBe('resident');

    // Never return the password or its hash.
    expect(body.user).not.toHaveProperty('password');
    expect(body.user).not.toHaveProperty('passwordHash');
  });

  it('securely hashes the password before storing it', async () => {
    mockUserFindUnique.mockResolvedValue(null);
    mockUserCreate.mockResolvedValue({
      id: TEST_USER_ID,
      email: TEST_EMAIL,
      role: 'resident',
      createdAt: new Date(),
    });

    await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: { email: TEST_EMAIL, password: TEST_PASSWORD },
    });

    const creationCall = mockUserCreate.mock.calls[0][0] as {
      data: { passwordHash: string };
      select: unknown;
    };
    const hash = creationCall.data.passwordHash;
    expect(hash).not.toBe(TEST_PASSWORD);
    expect(typeof hash).toBe('string');
    expect(await bcrypt.compare(TEST_PASSWORD, hash)).toBe(true);
  });

  it('returns 400 for missing fields', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {},
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.payload)).toHaveProperty('error');
  });

  it('returns 400 for an invalid email', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: { email: 'not-an-email', password: TEST_PASSWORD },
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.payload)).toHaveProperty('error');
  });

  it('returns 400 for a password shorter than 12 characters', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: { email: TEST_EMAIL, password: 'short1234' },
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.payload)).toHaveProperty('error');
  });

  it('returns 409 when the email already exists and does not create a user', async () => {
    mockUserFindUnique.mockResolvedValue({ id: 'existing-id', email: TEST_EMAIL });

    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: { email: TEST_EMAIL, password: TEST_PASSWORD },
    });

    expect(response.statusCode).toBe(409);
    expect(JSON.parse(response.payload)).toHaveProperty(
      'error',
      'An account with this email already exists.'
    );
    expect(mockUserCreate).not.toHaveBeenCalled();
  });

  it('always registers users as residents, even if admin is requested', async () => {
    mockUserFindUnique.mockResolvedValue(null);
    mockUserCreate.mockResolvedValue({
      id: TEST_USER_ID,
      email: TEST_EMAIL,
      role: 'resident',
      createdAt: new Date(),
    });

    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: { email: TEST_EMAIL, password: TEST_PASSWORD, role: 'admin' },
    });

    expect(response.statusCode).toBe(201);
    expect(JSON.parse(response.payload).user.role).toBe('resident');

    const creationCall = mockUserCreate.mock.calls[0][0] as {
      data: { role: string };
    };
    expect(creationCall.data.role).toBe('resident');
  });
});

describe('POST /auth/login', () => {
  let app: Awaited<ReturnType<typeof buildApp>>;

  beforeAll(async () => {
    app = await buildApp();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns 200 with a token and safe user info for valid credentials', async () => {
    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 12);
    mockUserFindUnique.mockResolvedValue({
      id: TEST_USER_ID,
      email: TEST_EMAIL,
      passwordHash,
      role: 'resident',
      createdAt: new Date('2024-01-01T00:00:00Z'),
    });

    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: TEST_EMAIL, password: TEST_PASSWORD },
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('token');
    expect(typeof body.token).toBe('string');
    expect(body.user.id).toBe(TEST_USER_ID);
    expect(body.user.email).toBe(TEST_EMAIL);
    expect(body.user.role).toBe('resident');

    // Never return the password or its hash.
    expect(body.user).not.toHaveProperty('password');
    expect(body.user).not.toHaveProperty('passwordHash');
  });

  it('returns 401 for an incorrect password', async () => {
    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 12);
    mockUserFindUnique.mockResolvedValue({
      id: TEST_USER_ID,
      email: TEST_EMAIL,
      passwordHash,
      role: 'resident',
      createdAt: new Date(),
    });

    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: TEST_EMAIL, password: 'WrongPass123456' },
    });

    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.payload)).toHaveProperty(
      'error',
      'Invalid email or password.'
    );
  });

  it('returns 401 when the email does not exist', async () => {
    mockUserFindUnique.mockResolvedValue(null);

    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: 'unknown@example.com', password: TEST_PASSWORD },
    });

    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.payload)).toHaveProperty(
      'error',
      'Invalid email or password.'
    );
  });

  it('returns 400 for invalid input', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {},
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.payload)).toHaveProperty('error');
  });
});

describe('GET /auth/me', () => {
  let app: Awaited<ReturnType<typeof buildApp>>;
  let token: string;

  beforeAll(async () => {
    app = await buildApp();
    token = await app.jwt.sign({
      sub: TEST_USER_ID,
      email: TEST_EMAIL,
      role: 'resident',
    });
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns 200 with safe user info for a valid token', async () => {
    mockUserFindUnique.mockResolvedValue({
      id: TEST_USER_ID,
      email: TEST_EMAIL,
      role: 'resident',
      createdAt: new Date('2024-01-01T00:00:00Z'),
    });

    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: { authorization: `Bearer ${token}` },
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    expect(body.user.id).toBe(TEST_USER_ID);
    expect(body.user.email).toBe(TEST_EMAIL);
    expect(body.user.role).toBe('resident');
    expect(body.user).not.toHaveProperty('passwordHash');
  });

  it('returns 401 without an authentication token', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
    });

    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.payload)).toHaveProperty('error');
  });

  it('returns 401 with an invalid authentication token', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: { authorization: 'Bearer invalid-token' },
    });

    expect(response.statusCode).toBe(401);
    expect(JSON.parse(response.payload)).toHaveProperty('error');
  });
});

describe('authentication middleware', () => {
  let app: Awaited<ReturnType<typeof buildApp>>;
  let residentToken: string;
  let adminToken: string;

  beforeAll(async () => {
    app = await buildApp();
    residentToken = await app.jwt.sign({
      sub: TEST_USER_ID,
      email: TEST_EMAIL,
      role: 'resident',
    });
    adminToken = await app.jwt.sign({
      sub: 'admin-id',
      email: 'admin@example.com',
      role: 'admin',
    });
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('/protected returns 401 without a token', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/protected',
    });

    expect(response.statusCode).toBe(401);
  });

  it('/protected returns 200 with a valid token', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/protected',
      headers: { authorization: `Bearer ${residentToken}` },
    });

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.payload)).toEqual({ ok: true, sub: TEST_USER_ID });
  });

  it('/admin-only returns 403 for a resident', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/admin-only',
      headers: { authorization: `Bearer ${residentToken}` },
    });

    expect(response.statusCode).toBe(403);
    expect(JSON.parse(response.payload)).toHaveProperty(
      'error',
      'Admin access required.'
    );
  });

  it('/admin-only returns 200 for an admin', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/admin-only',
      headers: { authorization: `Bearer ${adminToken}` },
    });

    expect(response.statusCode).toBe(200);
  });

  it('/admin-only returns 401 without a token', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/admin-only',
    });

    expect(response.statusCode).toBe(401);
  });
});
