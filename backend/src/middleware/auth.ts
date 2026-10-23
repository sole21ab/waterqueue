import type { FastifyRequest, FastifyReply } from 'fastify';

export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  try {
    await request.jwtVerify();
  } catch {
    reply.code(401).send({ error: 'Missing or invalid authentication token.' });
    return;
  }
}

export async function requireAdmin(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const payload = request.user as { role?: string } | undefined;
  if (!payload || payload.role !== 'admin') {
    reply.code(403).send({ error: 'Admin access required.' });
    return;
  }
}
