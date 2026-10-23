import 'dotenv/config';
import Fastify from 'fastify';
import jwt from '@fastify/jwt';
import cors from '@fastify/cors';
import { logger } from './utils/logger.js';
import healthRoutes from './routes/health.js';
import authRoutes from './routes/auth.js';
import waterPointsRoutes from './routes/waterPoints.js';
import votesRoutes from './routes/votes.js';

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

// Browser clients (Flutter Web) call this API from a different origin,
// so every response must carry the CORS headers the browser expects.
// `credentials: true` is required because admin requests send the
// `Authorization: Bearer` header; `methods` must include PUT/PATCH so the
// preflight for admin Save and Deactivate is allowed.
await fastify.register(cors, {
  origin: true,
  credentials: true,
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
});

fastify.register(healthRoutes);
fastify.register(authRoutes);
fastify.register(waterPointsRoutes);
fastify.register(votesRoutes);

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