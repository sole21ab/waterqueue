import { prisma } from '../prisma/client.js';
import { VoteType } from '@prisma/client';

export { VoteType };

const MAX_REPORT_AGE_MINUTES = 120;

export interface VoteResult {
  id: string;
  reportId: string;
  userId: string;
  voteType: VoteType;
  createdAt: Date;
}

export interface VoteValidationError {
  code: 'REPORT_NOT_FOUND' | 'REPORT_EXPIRED' | 'SELF_VOTE' | 'DUPLICATE_VOTE' | 'INVALID_VOTE_TYPE';
  message: string;
}

export async function createVote(
  userId: string,
  reportId: string,
  voteType: VoteType
): Promise<VoteResult | VoteValidationError> {
  const report = await prisma.report.findUnique({
    where: { id: reportId },
    select: {
      id: true,
      userId: true,
      createdAt: true,
    },
  });

  if (!report) {
    return {
      code: 'REPORT_NOT_FOUND',
      message: 'Report not found.',
    };
  }

  const now = new Date();
  const reportAgeMinutes = (now.getTime() - report.createdAt.getTime()) / (1000 * 60);

  if (reportAgeMinutes >= MAX_REPORT_AGE_MINUTES) {
    return {
      code: 'REPORT_EXPIRED',
      message: 'Cannot vote on reports older than 2 hours.',
    };
  }

  if (report.userId === userId) {
    return {
      code: 'SELF_VOTE',
      message: 'Cannot vote on your own report.',
    };
  }

  try {
    const vote = await prisma.vote.create({
      data: {
        reportId,
        userId,
        voteType,
      },
      select: {
        id: true,
        reportId: true,
        userId: true,
        voteType: true,
        createdAt: true,
      },
    });

    return vote;
  } catch (error) {
    if (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === 'P2002'
    ) {
      return {
        code: 'DUPLICATE_VOTE',
        message: 'You have already voted on this report.',
      };
    }
    throw error;
  }
}

export async function getVotesForReport(reportId: string): Promise<VoteResult[]> {
  return prisma.vote.findMany({
    where: { reportId },
    select: {
      id: true,
      reportId: true,
      userId: true,
      voteType: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'asc' },
  });
}

export async function getVotesForReports(reportIds: string[]): Promise<VoteResult[]> {
  if (reportIds.length === 0) return [];

  return prisma.vote.findMany({
    where: { reportId: { in: reportIds } },
    select: {
      id: true,
      reportId: true,
      userId: true,
      voteType: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'asc' },
  });
}

export function isVoteValidationError(result: VoteResult | VoteValidationError): result is VoteValidationError {
  return 'code' in result;
}