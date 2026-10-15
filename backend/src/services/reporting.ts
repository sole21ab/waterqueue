import { prisma } from '../prisma/client.js';

export type WaterAvailabilityStatus = 'available' | 'unavailable' | 'uncertain' | 'unknown';

export interface CurrentStatus {
  waterAvailable: WaterAvailabilityStatus;
  queueSize: number | 'unknown';
  estimatedWaitMinutes: number | 'unknown';
  confidence: number;
  lastReportedAt: string | null;
}

interface ReportData {
  waterAvailable: boolean;
  queueSize: number;
  createdAt: Date;
}

const MAX_AGE_MINUTES = 120;

function calculateWeight(reportAgeMinutes: number): number {
  if (reportAgeMinutes <= 0) return 1;
  if (reportAgeMinutes >= MAX_AGE_MINUTES) return 0;
  return 1 - reportAgeMinutes / MAX_AGE_MINUTES;
}

function weightedMedian(values: number[], weights: number[]): number {
  if (values.length === 0) return 0;

  const pairs = values.map((value, index) => ({ value, weight: weights[index] }))
    .filter(p => p.weight > 0)
    .sort((a, b) => a.value - b.value);

  if (pairs.length === 0) return 0;

  const totalWeight = pairs.reduce((sum, p) => sum + p.weight, 0);
  let cumulativeWeight = 0;

  for (const pair of pairs) {
    cumulativeWeight += pair.weight;
    if (cumulativeWeight >= totalWeight / 2) {
      return pair.value;
    }
  }

  return pairs[pairs.length - 1].value;
}

export async function calculateWaterPointStatus(waterPointId: string): Promise<CurrentStatus> {
  const now = new Date();
  const cutoffTime = new Date(now.getTime() - MAX_AGE_MINUTES * 60 * 1000);

  const reports = await prisma.report.findMany({
    where: {
      waterPointId,
      createdAt: {
        gte: cutoffTime,
      },
    },
    select: {
      waterAvailable: true,
      queueSize: true,
      createdAt: true,
    },
    orderBy: {
      createdAt: 'desc',
    },
  });

  const reportData: ReportData[] = reports.map(r => ({
    waterAvailable: r.waterAvailable,
    queueSize: r.queueSize,
    createdAt: r.createdAt,
  })).filter(r => {
    const ageMinutes = (now.getTime() - r.createdAt.getTime()) / (1000 * 60);
    return ageMinutes < MAX_AGE_MINUTES;
  });

  if (reportData.length === 0) {
    return {
      waterAvailable: 'unknown',
      queueSize: 'unknown',
      estimatedWaitMinutes: 'unknown',
      confidence: 0,
      lastReportedAt: null,
    };
  }

  const weights = reportData.map(r => {
    const ageMinutes = (now.getTime() - r.createdAt.getTime()) / (1000 * 60);
    return calculateWeight(ageMinutes);
  });

  const totalWeight = weights.reduce((sum, w) => sum + w, 0);
  const maxPossibleWeight = reports.length;

  const availabilityScore = reportData.reduce((sum, r, i) => {
    return sum + (r.waterAvailable ? 1 : 0) * weights[i];
  }, 0) / totalWeight;

  let waterAvailable: WaterAvailabilityStatus;
  if (availabilityScore >= 0.65) {
    waterAvailable = 'available';
  } else if (availabilityScore <= 0.35) {
    waterAvailable = 'unavailable';
  } else {
    waterAvailable = 'uncertain';
  }

  const queueSizes = reportData.map(r => r.queueSize);
  const medianQueueSize = Math.round(weightedMedian(queueSizes, weights));

  const confidence = Math.min(100, Math.max(0, Math.round((totalWeight / maxPossibleWeight) * 100)));

  const lastReportedAt = reports[0].createdAt.toISOString();

  return {
    waterAvailable,
    queueSize: medianQueueSize,
    estimatedWaitMinutes: medianQueueSize * 2,
    confidence,
    lastReportedAt,
  };
}