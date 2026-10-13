import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Fastify from 'fastify';
import healthRoutes from '../src/routes/health.js';

describe('GET /health', () => {
  let app: ReturnType<typeof Fastify>;

  beforeAll(async () => {
    app = Fastify({ logger: false });
    app.register(healthRoutes);
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 200 with status ok and timestamp', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
    });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload);
    expect(body).toHaveProperty('status', 'ok');
    expect(body).toHaveProperty('timestamp');
    expect(typeof body.timestamp).toBe('string');
    expect(() => new Date(body.timestamp)).not.toThrow();
  });
});