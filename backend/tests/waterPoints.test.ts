import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import Fastify from 'fastify';
import bcrypt from 'bcryptjs';
import jwt from '@fastify/jwt';

const { mockWaterPointFindMany, mockWaterPointFindFirst, mockWaterPointFindUnique, mockWaterPointCreate, mockWaterPointUpdate, mockWaterPointDelete, mockWaterPointDeleteMany, mockWaterPointUpsert, mockUserFindUnique, mockUserCreate, mockUserUpsert, mockUserDelete, mockUserDeleteMany, mockReportFindMany, mockReportCreate, mockReportDeleteMany, mockDisconnect } = vi.hoisted(() => ({
  mockWaterPointFindMany: vi.fn(),
  mockWaterPointFindFirst: vi.fn(),
  mockWaterPointFindUnique: vi.fn(),
  mockWaterPointCreate: vi.fn(),
  mockWaterPointUpdate: vi.fn(),
  mockWaterPointDelete: vi.fn(),
  mockWaterPointDeleteMany: vi.fn(),
  mockWaterPointUpsert: vi.fn(),
  mockUserFindUnique: vi.fn(),
  mockUserCreate: vi.fn(),
  mockUserUpsert: vi.fn(),
  mockUserDelete: vi.fn(),
  mockUserDeleteMany: vi.fn(),
  mockReportFindMany: vi.fn(),
  mockReportCreate: vi.fn(),
  mockReportDeleteMany: vi.fn(),
  mockDisconnect: vi.fn(),
}));

vi.mock('../src/prisma/client.js', () => ({
  prisma: {
    waterPoint: {
      findMany: mockWaterPointFindMany,
      findFirst: mockWaterPointFindFirst,
      findUnique: mockWaterPointFindUnique,
      create: mockWaterPointCreate,
      update: mockWaterPointUpdate,
      delete: mockWaterPointDelete,
      deleteMany: mockWaterPointDeleteMany,
      upsert: mockWaterPointUpsert,
    },
    user: {
      findUnique: mockUserFindUnique,
      create: mockUserCreate,
      upsert: mockUserUpsert,
      delete: mockUserDelete,
      deleteMany: mockUserDeleteMany,
    },
    report: {
      findMany: mockReportFindMany,
      create: mockReportCreate,
      deleteMany: mockReportDeleteMany,
    },
    $disconnect: mockDisconnect,
  },
}));

import waterPointsRoutes from '../src/routes/waterPoints.js';
import authRoutes from '../src/routes/auth.js';
import { prisma } from '../src/prisma/client.js';

const ACTIVE_WATER_POINT_ID = 'aaaaaaaa-bbbb-cccc-dddd-000000000001';
const INACTIVE_WATER_POINT_ID = 'bbbbbbbb-cccc-dddd-eeee-000000000006';
const NONEXISTENT_WATER_POINT_ID = 'cccccccc-dddd-eeee-ffff-000000000007';
const TEST_USER_EMAIL = 'test-resident@example.com';
const TEST_USER_PASSWORD = 'password123456';

let testUserId: string;
let testUserToken: string;

describe('GET /water-points', () => {
  let app: ReturnType<typeof Fastify>;

  beforeAll(async () => {
    app = Fastify({ logger: false });
    app.register(waterPointsRoutes);
    await app.ready();

    // Setup mock water points
    const mockActiveWaterPoints = [
      {
        id: ACTIVE_WATER_POINT_ID,
        name: 'Bole Medhanealem Well',
        address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
        latitude: 8.9867,
        longitude: 38.7993,
        operatingHours: '06:00-22:00',
        isActive: true,
        createdAt: new Date('2024-01-01T00:00:00Z'),
      },
      {
        id: 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
        name: 'Piazza Community Tap',
        address: 'Arada Subcity, Piazza District, Addis Ababa',
        latitude: 9.0333,
        longitude: 38.7500,
        operatingHours: '24/7',
        isActive: true,
        createdAt: new Date('2024-01-01T00:00:00Z'),
      },
    ];

    const mockInactiveWaterPoint = {
      id: INACTIVE_WATER_POINT_ID,
      name: 'Inactive Water Point',
      address: 'Test Address',
      latitude: 0,
      longitude: 0,
      operatingHours: '09:00-17:00',
      isActive: false,
      createdAt: new Date('2024-01-01T00:00:00Z'),
    };

    mockWaterPointFindMany.mockImplementation(({ where }) => {
      if (where?.isActive === false) {
        return Promise.resolve([mockInactiveWaterPoint]);
      }
      return Promise.resolve(mockActiveWaterPoints);
    });

    mockWaterPointFindFirst.mockImplementation(({ where }) => {
      if (where?.id === ACTIVE_WATER_POINT_ID && where?.isActive === true) {
        return Promise.resolve(mockActiveWaterPoints[0]);
      }
      if (where?.id === INACTIVE_WATER_POINT_ID) {
        return Promise.resolve(mockInactiveWaterPoint);
      }
      return Promise.resolve(null);
    });

    // No reports for any water point
    mockReportFindMany.mockResolvedValue([]);
  });

  afterAll(async () => {
    vi.clearAllMocks();
    await app.close();
  });

  it('returns 200 with active water points only by default', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/water-points',
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('waterPoints');
    expect(Array.isArray(body.waterPoints)).toBe(true);
    expect(body.waterPoints.length).toBeGreaterThan(0);

    for (const wp of body.waterPoints) {
      expect(wp.isActive).toBe(true);
      expect(wp).toHaveProperty('id');
      expect(wp).toHaveProperty('name');
      expect(wp).toHaveProperty('address');
      expect(wp).toHaveProperty('latitude');
      expect(wp).toHaveProperty('longitude');
      expect(wp).toHaveProperty('operatingHours');
      expect(wp).toHaveProperty('createdAt');
      expect(wp).toHaveProperty('currentStatus');
      expect(wp.currentStatus.waterAvailable).toBe('unknown');
      expect(wp.currentStatus.queueSize).toBe('unknown');
      expect(wp.currentStatus.estimatedWaitMinutes).toBe('unknown');
      expect(wp.currentStatus.confidence).toBe(0);
      expect(wp.currentStatus.lastReportedAt).toBeNull();
      expect(wp).not.toHaveProperty('passwordHash');
    }
  }, 15000);

  it('returns 200 with only active water points when isActive=true', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/water-points?isActive=true',
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    for (const wp of body.waterPoints) {
      expect(wp.isActive).toBe(true);
    }
  });

  it('returns 200 with only inactive water points when isActive=false', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/water-points?isActive=false',
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    for (const wp of body.waterPoints) {
      expect(wp.isActive).toBe(false);
    }
    expect(body.waterPoints.some((wp: { id: string }) => wp.id === INACTIVE_WATER_POINT_ID)).toBe(true);
  });

  it('returns 400 for invalid isActive query parameter', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/water-points?isActive=invalid',
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error');
  });

  it('returns empty array when no water points match filter', async () => {
    // Delete all inactive water points first (mock)
    mockWaterPointFindMany.mockImplementation(({ where }) => {
      if (where?.isActive === false) {
        return Promise.resolve([]);
      }
      return Promise.resolve([
        {
          id: ACTIVE_WATER_POINT_ID,
          name: 'Bole Medhanealem Well',
          address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
          latitude: 8.9867,
          longitude: 38.7993,
          operatingHours: '06:00-22:00',
          isActive: true,
          createdAt: new Date('2024-01-01T00:00:00Z'),
        },
        {
          id: 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
          name: 'Piazza Community Tap',
          address: 'Arada Subcity, Piazza District, Addis Ababa',
          latitude: 9.0333,
          longitude: 38.7500,
          operatingHours: '24/7',
          isActive: true,
          createdAt: new Date('2024-01-01T00:00:00Z'),
        },
      ]);
    });

    const response = await app.inject({
      method: 'GET',
      url: '/water-points?isActive=false',
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.payload);
    expect(body.waterPoints).toEqual([]);
  });
});

describe('GET /water-points/:id', () => {
  let app: ReturnType<typeof Fastify>;

  beforeAll(async () => {
    app = Fastify({ logger: false });
    app.register(waterPointsRoutes);
    await app.ready();

    // Setup mock water points for this test suite
    const mockActiveWaterPoint = {
      id: ACTIVE_WATER_POINT_ID,
      name: 'Bole Medhanealem Well',
      address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
      latitude: 8.9867,
      longitude: 38.7993,
      operatingHours: '06:00-22:00',
      isActive: true,
      createdAt: new Date('2024-01-01T00:00:00Z'),
    };

    const mockInactiveWaterPoint = {
      id: INACTIVE_WATER_POINT_ID,
      name: 'Inactive Water Point',
      address: 'Test Address',
      latitude: 0,
      longitude: 0,
      operatingHours: '09:00-17:00',
      isActive: false,
      createdAt: new Date('2024-01-01T00:00:00Z'),
    };

    mockWaterPointFindFirst.mockImplementation(({ where }) => {
      if (where?.id === ACTIVE_WATER_POINT_ID && where?.isActive === true) {
        return Promise.resolve(mockActiveWaterPoint);
      }
      if (where?.id === INACTIVE_WATER_POINT_ID && where?.isActive === true) {
        return Promise.resolve(null);
      }
      return Promise.resolve(null);
    });

    // No reports for any water point
    mockReportFindMany.mockResolvedValue([]);
  });

  afterAll(async () => {
    vi.clearAllMocks();
    await app.close();
  });

  it('returns 200 with water point when ID is valid and active', async () => {
    const response = await app.inject({
      method: 'GET',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}`,
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('waterPoint');
    const wp = body.waterPoint;
    expect(wp.id).toBe(ACTIVE_WATER_POINT_ID);
    expect(wp.isActive).toBe(true);
    expect(wp).toHaveProperty('name');
    expect(wp).toHaveProperty('address');
    expect(wp).toHaveProperty('latitude');
    expect(wp).toHaveProperty('longitude');
    expect(wp).toHaveProperty('operatingHours');
    expect(wp).toHaveProperty('createdAt');
    expect(wp).toHaveProperty('currentStatus');
    expect(wp.currentStatus.waterAvailable).toBe('unknown');
    expect(wp.currentStatus.queueSize).toBe('unknown');
    expect(wp.currentStatus.estimatedWaitMinutes).toBe('unknown');
    expect(wp.currentStatus.confidence).toBe(0);
    expect(wp.currentStatus.lastReportedAt).toBeNull();
    expect(wp).not.toHaveProperty('passwordHash');
  }, 15000);

  it('returns 404 when water point exists but is inactive', async () => {
    const response = await app.inject({
      method: 'GET',
      url: `/water-points/${INACTIVE_WATER_POINT_ID}`,
    });

    expect(response.statusCode).toBe(404);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Water point not found.');
  });

  it('returns 404 when water point does not exist', async () => {
    const response = await app.inject({
      method: 'GET',
      url: `/water-points/${NONEXISTENT_WATER_POINT_ID}`,
    });

    expect(response.statusCode).toBe(404);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Water point not found.');
  });

  it('returns 400 for invalid UUID format', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/water-points/not-a-uuid',
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid water point ID.');
  });

  it('returns 400 for empty ID (matches list route)', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/water-points/',
    });

    expect(response.statusCode).toBe(400);
  });
});

describe('POST /water-points/:id/reports', () => {
  let app: ReturnType<typeof Fastify>;

  beforeAll(async () => {
    app = Fastify({ logger: false });
    await app.register(jwt, {
      secret: process.env.JWT_SECRET || 'test-secret-key-that-is-at-least-32-chars-long',
      sign: { expiresIn: '24h' },
    });
    app.register(authRoutes);
    app.register(waterPointsRoutes);
    await app.ready();

    // Setup mock user
    testUserId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    const passwordHash = await bcrypt.hash(TEST_USER_PASSWORD, 12);
    const mockUser = {
      id: testUserId,
      email: TEST_USER_EMAIL,
      passwordHash,
      role: 'resident',
      createdAt: new Date('2024-01-01T00:00:00Z'),
    };
mockUserUpsert.mockResolvedValue(mockUser);

    mockUserFindUnique.mockResolvedValue(mockUser);

    // Setup mock water point
    const mockActiveWaterPoint = {
      id: ACTIVE_WATER_POINT_ID,
      name: 'Bole Medhanealem Well',
      address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
      latitude: 8.9867,
      longitude: 38.7993,
      operatingHours: '06:00-22:00',
      isActive: true,
      createdAt: new Date('2024-01-01T00:00:00Z'),
    };
    mockWaterPointFindFirst.mockImplementation(({ where }) => {
      if (where?.id === ACTIVE_WATER_POINT_ID && where?.isActive === true) {
        return Promise.resolve(mockActiveWaterPoint);
      }
      return Promise.resolve(null);
    });

    // Setup mock report creation
    mockReportCreate.mockImplementation(({ data }) => {
      return Promise.resolve({
        id: 'rrrrrrrr-rrrr-rrrr-rrrr-rrrrrrrrrrrr',
        waterPointId: data.waterPointId,
        userId: data.userId,
        waterAvailable: data.waterAvailable,
        queueSize: data.queueSize,
        estimatedWaitMinutes: null,
        createdAt: new Date(),
      });
    });

    // Login to get token
    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: TEST_USER_EMAIL, password: TEST_USER_PASSWORD },
    });
    const loginBody = JSON.parse(loginResponse.payload);
    testUserToken = loginBody.token;
  });

  afterAll(async () => {
    vi.clearAllMocks();
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns 201 with report when authenticated and valid data', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 5 },
    });

    expect(response.statusCode).toBe(201);

    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('report');
    const report = body.report;
    expect(report.waterPointId).toBe(ACTIVE_WATER_POINT_ID);
    expect(report.userId).toBe(testUserId);
    expect(report.waterAvailable).toBe(true);
    expect(report.queueSize).toBe(5);
    expect(report).toHaveProperty('id');
    expect(report).toHaveProperty('createdAt');
    expect(report.estimatedWaitMinutes).toBeNull();
  });

  it('returns 401 when no authentication token provided', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      payload: { waterAvailable: true, queueSize: 5 },
    });

    expect(response.statusCode).toBe(401);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Missing or invalid authentication token.');
  });

  it('returns 401 when authentication token is invalid', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: 'Bearer invalid-token' },
      payload: { waterAvailable: true, queueSize: 5 },
    });

    expect(response.statusCode).toBe(401);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Missing or invalid authentication token.');
  });

  it('returns 400 for invalid water point ID format', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/water-points/not-a-uuid/reports',
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 5 },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid water point ID.');
  });

  it('returns 404 for non-existent water point', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${NONEXISTENT_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 5 },
    });

    expect(response.statusCode).toBe(404);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Water point not found.');
  });

  it('returns 404 for inactive water point', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${INACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 5 },
    });

    expect(response.statusCode).toBe(404);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Water point not found.');
  });

  it('returns 400 when waterAvailable is missing', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { queueSize: 5 },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid request body.');
    expect(body.details).toHaveProperty('waterAvailable');
  });

  it('returns 400 when queueSize is missing', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid request body.');
    expect(body.details).toHaveProperty('queueSize');
  });

  it('returns 400 when queueSize is negative', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: -1 },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid request body.');
    expect(body.details).toHaveProperty('queueSize');
  });

  it('returns 400 when queueSize exceeds 50', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 51 },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid request body.');
    expect(body.details).toHaveProperty('queueSize');
  });

  it('returns 400 when queueSize is not an integer', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 5.5 },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid request body.');
    expect(body.details).toHaveProperty('queueSize');
  });

  it('allows queueSize of 0', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: false, queueSize: 0 },
    });

    expect(response.statusCode).toBe(201);
    const body = JSON.parse(response.payload);
    expect(body.report.queueSize).toBe(0);
    expect(body.report.waterAvailable).toBe(false);
  });

  it('allows queueSize of 50', async () => {
    const response = await app.inject({
      method: 'POST',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/reports`,
      headers: { authorization: `Bearer ${testUserToken}` },
      payload: { waterAvailable: true, queueSize: 50 },
    });

    expect(response.statusCode).toBe(201);
    const body = JSON.parse(response.payload);
    expect(body.report.queueSize).toBe(50);
  });
});

describe('Admin water-point management', () => {
  let app: ReturnType<typeof Fastify>;
  let adminToken: string;
  let residentToken: string;
  const adminUserId = 'admin-user-id-0000-0000-000000000001';
  const residentUserId = 'resident-user-id-0000-0000-000000000002';

  const mockAdminUser = {
    id: adminUserId,
    email: 'admin@example.com',
    passwordHash: 'hashed',
    role: 'admin',
    createdAt: new Date('2024-01-01T00:00:00Z'),
  };

  const mockResidentUser = {
    id: residentUserId,
    email: 'resident@example.com',
    passwordHash: 'hashed',
    role: 'resident',
    createdAt: new Date('2024-01-01T00:00:00Z'),
  };

  const mockActiveWaterPoint = {
    id: ACTIVE_WATER_POINT_ID,
    name: 'Bole Medhanealem Well',
    address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
    latitude: 8.9867,
    longitude: 38.7993,
    operatingHours: '06:00-22:00',
    isActive: true,
    createdAt: new Date('2024-01-01T00:00:00Z'),
  };

  beforeAll(async () => {
    app = Fastify({ logger: false });
    await app.register(jwt, {
      secret: process.env.JWT_SECRET || 'test-secret-key-that-is-at-least-32-chars-long',
      sign: { expiresIn: '24h' },
    });
    app.register(authRoutes);
    app.register(waterPointsRoutes);
    await app.ready();

    const adminPasswordHash = await bcrypt.hash('AdminPass123456', 12);
    const residentPasswordHash = await bcrypt.hash('ResidentPass123456', 12);

    mockUserFindUnique.mockImplementation(({ where }) => {
      if (where.email === 'admin@example.com') {
        return Promise.resolve({ ...mockAdminUser, passwordHash: adminPasswordHash });
      }
      if (where.email === 'resident@example.com') {
        return Promise.resolve({ ...mockResidentUser, passwordHash: residentPasswordHash });
      }
      return Promise.resolve(null);
    });

    const adminLogin = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: 'admin@example.com', password: 'AdminPass123456' },
    });
    adminToken = JSON.parse(adminLogin.payload).token;

    const residentLogin = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: 'resident@example.com', password: 'ResidentPass123456' },
    });
    residentToken = JSON.parse(residentLogin.payload).token;
  });

  afterAll(async () => {
    vi.clearAllMocks();
    await app.close();
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('POST /water-points returns 201 for admin', async () => {
    const created = {
      id: 'new-wp-id',
      name: 'New Water Point',
      address: 'New Address',
      latitude: 9.0,
      longitude: 38.8,
      operatingHours: '08:00-18:00',
      isActive: true,
      createdAt: new Date(),
    };
    mockWaterPointCreate.mockResolvedValue(created);

    const response = await app.inject({
      method: 'POST',
      url: '/water-points',
      headers: { authorization: `Bearer ${adminToken}` },
      payload: {
        name: 'New Water Point',
        address: 'New Address',
        latitude: 9.0,
        longitude: 38.8,
        operatingHours: '08:00-18:00',
      },
    });

    expect(response.statusCode).toBe(201);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('waterPoint');
    expect(body.waterPoint.name).toBe('New Water Point');
    expect(body.waterPoint.isActive).toBe(true);
    expect(mockWaterPointCreate).toHaveBeenCalledWith({
      data: {
        name: 'New Water Point',
        address: 'New Address',
        latitude: 9.0,
        longitude: 38.8,
        operatingHours: '08:00-18:00',
        isActive: true,
      },
      select: expect.anything(),
    });
  });

  it('POST /water-points returns 403 for non-admin user', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/water-points',
      headers: { authorization: `Bearer ${residentToken}` },
      payload: {
        name: 'New Water Point',
        address: 'New Address',
        latitude: 9.0,
        longitude: 38.8,
        operatingHours: '08:00-18:00',
      },
    });

    expect(response.statusCode).toBe(403);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Admin access required.');
  });

  it('POST /water-points returns 401 without authentication token', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/water-points',
      payload: {
        name: 'New Water Point',
        address: 'New Address',
        latitude: 9.0,
        longitude: 38.8,
        operatingHours: '08:00-18:00',
      },
    });

    expect(response.statusCode).toBe(401);
  });

  it('POST /water-points returns 400 for invalid body', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/water-points',
      headers: { authorization: `Bearer ${adminToken}` },
      payload: { name: '', address: 'New Address', latitude: 9.0, longitude: 38.8, operatingHours: '08:00-18:00' },
    });

    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('error', 'Invalid request body.');
  });

  it('PUT /water-points/:id returns 200 for admin', async () => {
    const updated = {
      id: ACTIVE_WATER_POINT_ID,
      name: 'Updated Name',
      address: 'Updated Address',
      latitude: 9.0,
      longitude: 38.8,
      operatingHours: '09:00-19:00',
      isActive: true,
      createdAt: new Date(),
    };
    mockWaterPointFindUnique.mockResolvedValue(mockActiveWaterPoint);
    mockWaterPointUpdate.mockResolvedValue(updated);

    const response = await app.inject({
      method: 'PUT',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}`,
      headers: { authorization: `Bearer ${adminToken}` },
      payload: { name: 'Updated Name', operatingHours: '09:00-19:00' },
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('waterPoint');
    expect(body.waterPoint.name).toBe('Updated Name');
    expect(mockWaterPointUpdate).toHaveBeenCalledWith({
      where: { id: ACTIVE_WATER_POINT_ID },
      data: { name: 'Updated Name', operatingHours: '09:00-19:00' },
      select: expect.anything(),
    });
  });

  it('PUT /water-points/:id returns 404 when water point does not exist', async () => {
    mockWaterPointFindUnique.mockResolvedValue(null);

    const response = await app.inject({
      method: 'PUT',
      url: `/water-points/${NONEXISTENT_WATER_POINT_ID}`,
      headers: { authorization: `Bearer ${adminToken}` },
      payload: { name: 'X' },
    });

    expect(response.statusCode).toBe(404);
  });

  it('PUT /water-points/:id returns 403 for non-admin user', async () => {
    mockWaterPointFindUnique.mockResolvedValue(mockActiveWaterPoint);

    const response = await app.inject({
      method: 'PUT',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}`,
      headers: { authorization: `Bearer ${residentToken}` },
      payload: { name: 'X' },
    });

    expect(response.statusCode).toBe(403);
    // A resident must not be able to trigger an admin side-effect.
    expect(mockWaterPointUpdate).not.toHaveBeenCalled();
  });

  it('PUT /water-points/:id returns 401 without authentication token', async () => {
    mockWaterPointFindUnique.mockResolvedValue(mockActiveWaterPoint);

    const response = await app.inject({
      method: 'PUT',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}`,
      payload: { name: 'X' },
    });

    expect(response.statusCode).toBe(401);
    // No admin side-effect may run without authentication.
    expect(mockWaterPointUpdate).not.toHaveBeenCalled();
  });

  it('PUT /water-points/:id returns 400 for empty body', async () => {
    mockWaterPointFindUnique.mockResolvedValue(mockActiveWaterPoint);

    const response = await app.inject({
      method: 'PUT',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}`,
      headers: { authorization: `Bearer ${adminToken}` },
      payload: {},
    });

    expect(response.statusCode).toBe(400);
  });

  it('PUT /water-points/:id returns 400 for invalid ID', async () => {
    const response = await app.inject({
      method: 'PUT',
      url: '/water-points/not-a-uuid',
      headers: { authorization: `Bearer ${adminToken}` },
      payload: { name: 'X' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('PATCH /water-points/:id/deactivate returns 200 for admin', async () => {
    const deactivated = { ...mockActiveWaterPoint, isActive: false };
    mockWaterPointFindUnique.mockResolvedValue(mockActiveWaterPoint);
    mockWaterPointUpdate.mockResolvedValue(deactivated);

    const response = await app.inject({
      method: 'PATCH',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/deactivate`,
      headers: { authorization: `Bearer ${adminToken}` },
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.payload);
    expect(body.waterPoint.isActive).toBe(false);
    expect(mockWaterPointUpdate).toHaveBeenCalledWith({
      where: { id: ACTIVE_WATER_POINT_ID },
      data: { isActive: false },
      select: expect.anything(),
    });
  });

  it('PATCH /water-points/:id/deactivate returns 404 when water point does not exist', async () => {
    mockWaterPointFindUnique.mockResolvedValue(null);

    const response = await app.inject({
      method: 'PATCH',
      url: `/water-points/${NONEXISTENT_WATER_POINT_ID}/deactivate`,
      headers: { authorization: `Bearer ${adminToken}` },
    });

    expect(response.statusCode).toBe(404);
  });

  it('PATCH /water-points/:id/deactivate returns 403 for non-admin user', async () => {
    mockWaterPointFindUnique.mockResolvedValue(mockActiveWaterPoint);

    const response = await app.inject({
      method: 'PATCH',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/deactivate`,
      headers: { authorization: `Bearer ${residentToken}` },
    });

    expect(response.statusCode).toBe(403);
    // A resident must not be able to trigger an admin side-effect.
    expect(mockWaterPointUpdate).not.toHaveBeenCalled();
  });

  it('PATCH /water-points/:id/deactivate returns 401 without authentication token', async () => {
    const response = await app.inject({
      method: 'PATCH',
      url: `/water-points/${ACTIVE_WATER_POINT_ID}/deactivate`,
    });

    expect(response.statusCode).toBe(401);
    // No admin side-effect may run without authentication.
    expect(mockWaterPointUpdate).not.toHaveBeenCalled();
  });
});