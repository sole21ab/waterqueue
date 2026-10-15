import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import Fastify from 'fastify';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from '@fastify/jwt';
import waterPointsRoutes from '../src/routes/waterPoints.js';
import authRoutes from '../src/routes/auth.js';

const prisma = new PrismaClient();

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

    // Create an inactive water point for testing
    await prisma.waterPoint.upsert({
      where: { id: INACTIVE_WATER_POINT_ID },
      update: { isActive: false },
      create: {
        id: INACTIVE_WATER_POINT_ID,
        name: 'Inactive Water Point',
        address: 'Test Address',
        latitude: 0,
        longitude: 0,
        operatingHours: '09:00-17:00',
        isActive: false,
      },
    });
  });

  afterAll(async () => {
    await prisma.waterPoint.delete({ where: { id: INACTIVE_WATER_POINT_ID } }).catch(() => {});
    await app.close();
    await prisma.$disconnect();
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
      expect(wp.currentStatus.lastReportedAt).toBeNull();
      expect(wp).not.toHaveProperty('passwordHash');
    }
  });

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
    // Delete all inactive water points first
    await prisma.waterPoint.deleteMany({ where: { isActive: false } });

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
  });

  afterAll(async () => {
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
    expect(wp.currentStatus.lastReportedAt).toBeNull();
    expect(wp).not.toHaveProperty('passwordHash');
  });

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

    // Create test user and get token
    const passwordHash = await bcrypt.hash(TEST_USER_PASSWORD, 12);
    const user = await prisma.user.upsert({
      where: { email: TEST_USER_EMAIL },
      update: { passwordHash },
      create: {
        email: TEST_USER_EMAIL,
        passwordHash,
        role: 'resident',
      },
    });
    testUserId = user.id;

    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: TEST_USER_EMAIL, password: TEST_USER_PASSWORD },
    });
    const loginBody = JSON.parse(loginResponse.payload);
    testUserToken = loginBody.token;
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { email: TEST_USER_EMAIL } }).catch(() => {});
    await prisma.report.deleteMany({ where: { userId: testUserId } }).catch(() => {});
    await app.close();
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    // Clean up reports before each test
    await prisma.report.deleteMany({ where: { userId: testUserId } }).catch(() => {});
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