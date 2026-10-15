import 'dotenv/config';
import Fastify from 'fastify';
import jwt from '@fastify/jwt';
import { logger } from './utils/logger.js';
import healthRoutes from './routes/health.js';
import authRoutes from './routes/auth.js';
import waterPointsRoutes from './routes/waterPoints.js';

const fastify = Fastify({
  logger: false,
});

const jwtSecret = process.env.JWT_SECRET;

if (!jwtSecret || jwtSecret.length < 32) {
  throw new Error('JWT_SECRET must be configured with a strong secret.');
}

await fastify.register(jwt, {
  secret: jwtSecret,
  sign: {
    expiresIn: '24h',
  },
});

fastify.register(healthRoutes);
fastify.register(authRoutes);
fastify.register(waterPointsRoutes);

const start = async () => {
  try {
    const port = Number(process.env.PORT) || 3000;
    const host = process.env.HOST || '0.0.0.0';

    await fastify.listen({ port, host });
    logger.info(`Server listening on http://${host}:${port}`);
  } catch (err) {
    logger.error('Failed to start server', { error: String(err) });
    process.exit(1);
  }
};

start();