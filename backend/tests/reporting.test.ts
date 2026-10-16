import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('../src/prisma/client.js', () => ({
  prisma: {
    report: {
      findMany: vi.fn(),
    },
  },
}));

import { calculateWaterPointStatus, type CurrentStatus } from '../src/services/reporting.js';
import { prisma } from '../src/prisma/client.js';

const TEST_WATER_POINT_ID = 'aaaaaaaa-bbbb-cccc-dddd-000000000001';

const mockFindMany = prisma.report.findMany as ReturnType<typeof vi.fn>;

describe('calculateWaterPointStatus', () => {
  const now = new Date('2024-01-15T12:00:00Z');
  const originalDate = global.Date;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    vi.setSystemTime(now);
  });

  afterEach(() => {
    vi.useRealTimers();
    global.Date = originalDate;
  });

  it('returns unknown status when no reports exist', async () => {
    mockFindMany.mockResolvedValue([]);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result).toEqual({
      waterAvailable: 'unknown',
      queueSize: 'unknown',
      estimatedWaitMinutes: 'unknown',
      confidence: 0,
      lastReportedAt: null,
    });
  });

  it('returns unknown status when all reports are older than 2 hours', async () => {
    const oldReport = {
      waterAvailable: true,
      queueSize: 5,
      createdAt: new Date('2024-01-15T09:00:00Z'),
      votes: [],
    };
    mockFindMany.mockResolvedValue([oldReport]);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('unknown');
    expect(result.queueSize).toBe('unknown');
    expect(result.confidence).toBe(0);
    expect(result.lastReportedAt).toBeNull();
  });

  it('calculates available status when score >= 0.65', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 3, createdAt: new Date('2024-01-15T11:55:00Z'), votes: [] },
      { waterAvailable: true, queueSize: 4, createdAt: new Date('2024-01-15T11:50:00Z'), votes: [] },
      { waterAvailable: true, queueSize: 2, createdAt: new Date('2024-01-15T11:45:00Z'), votes: [] },
      { waterAvailable: false, queueSize: 10, createdAt: new Date('2024-01-15T11:40:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('available');
    expect(typeof result.queueSize).toBe('number');
    expect(typeof result.estimatedWaitMinutes).toBe('number');
    expect(result.confidence).toBeGreaterThan(0);
    expect(result.lastReportedAt).toBe('2024-01-15T11:55:00.000Z');
  });

  it('calculates unavailable status when score <= 0.35', async () => {
    const reports = [
      { waterAvailable: false, queueSize: 0, createdAt: new Date('2024-01-15T11:55:00Z'), votes: [] },
      { waterAvailable: false, queueSize: 0, createdAt: new Date('2024-01-15T11:50:00Z'), votes: [] },
      { waterAvailable: false, queueSize: 0, createdAt: new Date('2024-01-15T11:45:00Z'), votes: [] },
      { waterAvailable: true, queueSize: 5, createdAt: new Date('2024-01-15T11:40:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('unavailable');
    expect(typeof result.queueSize).toBe('number');
  });

  it('calculates uncertain status when score between 0.35 and 0.65', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 3, createdAt: new Date('2024-01-15T11:55:00Z'), votes: [] },
      { waterAvailable: true, queueSize: 4, createdAt: new Date('2024-01-15T11:50:00Z'), votes: [] },
      { waterAvailable: false, queueSize: 10, createdAt: new Date('2024-01-15T11:45:00Z'), votes: [] },
      { waterAvailable: false, queueSize: 8, createdAt: new Date('2024-01-15T11:40:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('uncertain');
  });

  it('calculates weighted median queue size correctly', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 10, createdAt: new Date('2024-01-15T11:59:00Z'), votes: [] },
      { waterAvailable: true, queueSize: 2, createdAt: new Date('2024-01-15T11:00:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(typeof result.queueSize).toBe('number');
    expect(result.queueSize).toBe(10);
  });

  it('calculates confidence based on total weight', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 3, createdAt: new Date('2024-01-15T11:59:00Z'), votes: [] },
      { waterAvailable: true, queueSize: 4, createdAt: new Date('2024-01-15T11:58:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.confidence).toBe(66);
  });

  it('bounds confidence between 0 and 100', async () => {
    const reports = Array.from({ length: 10 }, (_, i) => ({
      waterAvailable: true,
      queueSize: 3,
      createdAt: new Date(now.getTime() - (i + 1) * 60 * 1000),
      votes: [],
    }));
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.confidence).toBeGreaterThanOrEqual(0);
    expect(result.confidence).toBeLessThanOrEqual(100);
  });

  it('gives newer reports higher weight', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 1, createdAt: new Date('2024-01-15T11:59:00Z'), votes: [] },
      { waterAvailable: false, queueSize: 50, createdAt: new Date('2024-01-15T10:30:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('available');
    expect(result.queueSize).toBe(1);
  });

  it('handles single recent report', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 7, createdAt: new Date('2024-01-15T11:30:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('available');
    expect(result.queueSize).toBe(7);
    expect(result.estimatedWaitMinutes).toBe(14);
    expect(result.confidence).toBe(50);
    expect(result.lastReportedAt).toBe('2024-01-15T11:30:00.000Z');
  });

  it('excludes reports exactly at 120 minutes boundary', async () => {
    const reports = [
      { waterAvailable: true, queueSize: 5, createdAt: new Date('2024-01-15T10:00:00Z'), votes: [] },
    ];
    mockFindMany.mockResolvedValue(reports);

    const result = await calculateWaterPointStatus(TEST_WATER_POINT_ID);

    expect(result.waterAvailable).toBe('unknown');
  });
});
