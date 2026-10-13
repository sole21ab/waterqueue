import { prisma } from '../prisma/client.js';
import { logger } from '../utils/logger.js';

export async function checkDatabaseConnection(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    logger.info('Database connection successful');
    return true;
  } catch (error) {
    logger.error('Database connection failed', { error: String(error) });
    return false;
  } finally {
    await prisma.$disconnect();
  }
}