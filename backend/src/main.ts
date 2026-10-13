import Fastify from 'fastify';
import { logger } from './utils/logger.js';
import healthRoutes from './routes/health.js';

const fastify = Fastify({
  logger: false,
});

fastify.register(healthRoutes);

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