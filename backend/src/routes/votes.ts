import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { prisma } from '../prisma/client.js';
import { createVote, isVoteValidationError, VoteType } from '../services/voteService.js';

const reportIdSchema = z.string().uuid();

const voteBodySchema = z.object({
  voteType: z.enum(['confirm', 'contradict']),
});

const votesRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.post<{
    Params: { id: string };
    Body: z.infer<typeof voteBodySchema>;
  }>(
    '/reports/:id/votes',
    async (request, reply) => {
      try {
        await request.jwtVerify();
      } catch {
        return reply.code(401).send({ error: 'Missing or invalid authentication token.' });
      }

      const payload = request.user as { sub?: string };
      if (!payload.sub) {
        return reply.code(401).send({ error: 'Unauthorized.' });
      }

      const userId = payload.sub;

      const idParsed = reportIdSchema.safeParse(request.params.id);
      if (!idParsed.success) {
        return reply.code(400).send({ error: 'Invalid report ID.' });
      }

      const bodyParsed = voteBodySchema.safeParse(request.body);
      if (!bodyParsed.success) {
        return reply.code(400).send({
          error: 'Invalid request body.',
          details: bodyParsed.error.flatten().fieldErrors,
        });
      }

      const { voteType } = bodyParsed.data;

      const result = await createVote(userId, idParsed.data, voteType);

      if (isVoteValidationError(result)) {
        const statusCode = result.code === 'REPORT_NOT_FOUND' ? 404
          : result.code === 'REPORT_EXPIRED' ? 400
          : result.code === 'SELF_VOTE' ? 400
          : result.code === 'DUPLICATE_VOTE' ? 409
          : 400;
        return reply.code(statusCode).send({ error: result.message });
      }

      return reply.code(201).send({ vote: result });
    }
  );
};

export default votesRoutes;