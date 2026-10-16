import { prisma } from '../prisma/client.js';

export type WaterAvailabilityStatus = 'available' | 'unavailable' | 'uncertain' | 'unknown';

export interface CurrentStatus {
  waterAvailable: WaterAvailabilityStatus;
  queueSize: number | 'unknown';
  estimatedWaitMinutes: number | 'unknown';
  confidence: number;
  lastReportedAt: string | null;
}

interface ReportWithVotes {
  id: string;
  waterAvailable: boolean;
  queueSize: number;
  createdAt: Date;
  votes: { voteType: 'confirm' | 'contradict' }[];
}

const MAX_AGE_MINUTES = 120;

function calculateRecencyWeight(reportAgeMinutes: number): number {
  if (reportAgeMinutes <= 0) return 1;
  if (reportAgeMinutes >= MAX_AGE_MINUTES) return 0;
  return 1 - reportAgeMinutes / MAX_AGE_MINUTES;
}

function calculateVoteFactor(confirms: number, contradicts: number): number {
  const voteFactor = 1.0 + 0.1 * confirms - 0.15 * contradicts;
  return Math.min(1.5, Math.max(0.2, voteFactor));
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
      id: true,
      waterAvailable: true,
      queueSize: true,
      createdAt: true,
      votes: {
        select: {
          voteType: true,
        },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
  });

  const reportData: ReportWithVotes[] = reports.map(r => ({
    id: r.id,
    waterAvailable: r.waterAvailable,
    queueSize: r.queueSize,
    createdAt: r.createdAt,
    votes: r.votes,
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

  const votesByReportId = new Map<string, { confirms: number; contradicts: number }>();
  for (const report of reportData) {
    const entry = { confirms: 0, contradicts: 0 };
    for (const vote of report.votes ?? []) {
      if (vote.voteType === 'confirm') {
        entry.confirms += 1;
      } else {
        entry.contradicts += 1;
      }
    }
    votesByReportId.set(report.id, entry);
  }

  const effectiveWeights: number[] = [];
  let availableWeight = 0;
  let totalEffectiveWeight = 0;

  for (const report of reportData) {
    const ageMinutes = (now.getTime() - report.createdAt.getTime()) / (1000 * 60);
    const recencyWeight = calculateRecencyWeight(ageMinutes);

    const voteCounts = votesByReportId.get(report.id) || { confirms: 0, contradicts: 0 };
    const voteFactor = calculateVoteFactor(voteCounts.confirms, voteCounts.contradicts);

    const effectiveWeight = recencyWeight * voteFactor;
    effectiveWeights.push(effectiveWeight);
    totalEffectiveWeight += effectiveWeight;

    if (report.waterAvailable) {
      availableWeight += effectiveWeight;
    }
  }

  const availabilityRatio = totalEffectiveWeight > 0 ? availableWeight / totalEffectiveWeight : 0;

  let waterAvailable: WaterAvailabilityStatus;
  if (availabilityRatio >= 0.65) {
    waterAvailable = 'available';
  } else if (availabilityRatio <= 0.35) {
    waterAvailable = 'unavailable';
  } else {
    waterAvailable = 'uncertain';
  }

  const availableReports = reportData
    .map((r, i) => ({ queueSize: r.queueSize, weight: effectiveWeights[i], waterAvailable: r.waterAvailable }))
    .filter(r => r.weight > 0 && r.waterAvailable);

  let medianQueueSize = 0;
  if (availableReports.length > 0) {
    const queueSizes = availableReports.map(r => r.queueSize);
    const weights = availableReports.map(r => r.weight);
    medianQueueSize = Math.round(weightedMedian(queueSizes, weights));
  }

  const N = reportData.length;
  const maxPossibleEffectiveWeight = N * 1.5;
  const confidence = Math.min(100, Math.max(0, Math.round((totalEffectiveWeight / maxPossibleEffectiveWeight) * 100)));

  const lastReportedAt = reports[0].createdAt.toISOString();

  return {
    waterAvailable,
    queueSize: medianQueueSize,
    estimatedWaitMinutes: medianQueueSize * 2,
    confidence,
    lastReportedAt,
  };
}