import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { prisma } from '../prisma/client.js';
import { calculateWaterPointStatus, type CurrentStatus } from '../services/reporting.js';
import { authenticate, requireAdmin } from '../middleware/auth.js';

const waterPointIdSchema = z.string().uuid();

const listQuerySchema = z.object({
  isActive: z
    .enum(['true', 'false'])
    .optional()
    .default('true')
    .transform((val) => val === 'true'),
});

const reportSchema = z.object({
  waterAvailable: z.boolean(),
  queueSize: z.number().int().min(0).max(50),
});

const createWaterPointSchema = z.object({
  name: z.string().trim().min(1).max(255),
  address: z.string().trim().min(1).max(500),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  operatingHours: z.string().trim().min(1).max(100),
  isActive: z.boolean().optional().default(true),
});

const updateWaterPointSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  address: z.string().trim().min(1).max(500).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  operatingHours: z.string().trim().min(1).max(100).optional(),
  isActive: z.boolean().optional(),
});

type WaterPointResponse = {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  operatingHours: string;
  isActive: boolean;
  createdAt: string;
  currentStatus: CurrentStatus;
};

const waterPointsRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.get<{ Querystring: z.infer<typeof listQuerySchema> }>(
    '/water-points',
    async (request, reply) => {
      const parsed = listQuerySchema.safeParse(request.query);

      if (!parsed.success) {
        return reply.code(400).send({
          error: 'Invalid query parameters.',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { isActive } = parsed.data;

      try {
        const waterPoints = await prisma.waterPoint.findMany({
          where: { isActive },
          orderBy: { name: 'asc' },
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            operatingHours: true,
            isActive: true,
            createdAt: true,
          },
        });

        const response = await Promise.all(
          waterPoints.map(async (wp): Promise<WaterPointResponse> => {
            const currentStatus = await calculateWaterPointStatus(wp.id);
            return {
              id: wp.id,
              name: wp.name,
              address: wp.address,
              latitude: Number(wp.latitude),
              longitude: Number(wp.longitude),
              operatingHours: wp.operatingHours,
              isActive: wp.isActive,
              createdAt: wp.createdAt.toISOString(),
              currentStatus,
            };
          })
        );

        return reply.send({ waterPoints: response });
      } catch (error) {
        request.log.error({ err: error }, 'Failed to fetch water points');
        return reply.code(500).send({ error: 'Unable to fetch water points.' });
      }
    }
  );

  fastify.get<{ Params: { id: string } }>(
    '/water-points/:id',
    async (request, reply) => {
      const parsed = waterPointIdSchema.safeParse(request.params.id);

      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid water point ID.' });
      }

      try {
        const waterPoint = await prisma.waterPoint.findFirst({
          where: {
            id: parsed.data,
            isActive: true,
          },
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            operatingHours: true,
            isActive: true,
            createdAt: true,
          },
        });

        if (!waterPoint) {
          return reply.code(404).send({ error: 'Water point not found.' });
        }

        const currentStatus = await calculateWaterPointStatus(waterPoint.id);

        const response: WaterPointResponse = {
          id: waterPoint.id,
          name: waterPoint.name,
          address: waterPoint.address,
          latitude: Number(waterPoint.latitude),
          longitude: Number(waterPoint.longitude),
          operatingHours: waterPoint.operatingHours,
          isActive: waterPoint.isActive,
          createdAt: waterPoint.createdAt.toISOString(),
          currentStatus,
        };

        return reply.send({ waterPoint: response });
      } catch (error) {
        request.log.error({ err: error }, 'Failed to fetch water point');
        return reply.code(500).send({ error: 'Unable to fetch water point.' });
      }
    }
  );

  fastify.post<{
    Params: { id: string };
    Body: z.infer<typeof reportSchema>;
  }>(
    '/water-points/:id/reports',
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

      const idParsed = waterPointIdSchema.safeParse(request.params.id);
      if (!idParsed.success) {
        return reply.code(400).send({ error: 'Invalid water point ID.' });
      }

      const bodyParsed = reportSchema.safeParse(request.body);
      if (!bodyParsed.success) {
        return reply.code(400).send({
          error: 'Invalid request body.',
          details: bodyParsed.error.flatten().fieldErrors,
        });
      }

      const { waterAvailable, queueSize } = bodyParsed.data;

      try {
        const waterPoint = await prisma.waterPoint.findFirst({
          where: {
            id: idParsed.data,
            isActive: true,
          },
        });

        if (!waterPoint) {
          return reply.code(404).send({ error: 'Water point not found.' });
        }

        const report = await prisma.report.create({
          data: {
            waterPointId: idParsed.data,
            userId: payload.sub,
            waterAvailable,
            queueSize,
          },
          select: {
            id: true,
            waterPointId: true,
            userId: true,
            waterAvailable: true,
            queueSize: true,
            estimatedWaitMinutes: true,
            createdAt: true,
          },
        });

        return reply.code(201).send({ report });
      } catch (error) {
        request.log.error({ err: error }, 'Failed to create report');
        return reply.code(500).send({ error: 'Unable to submit report.' });
      }
    }
  );

  // Admin: create a new water point.
  fastify.post<{ Body: z.infer<typeof createWaterPointSchema> }>(
    '/water-points',
    { preHandler: [authenticate, requireAdmin] },
    async (request, reply) => {
      const bodyParsed = createWaterPointSchema.safeParse(request.body);

      if (!bodyParsed.success) {
        return reply.code(400).send({
          error: 'Invalid request body.',
          details: bodyParsed.error.flatten().fieldErrors,
        });
      }

      const { name, address, latitude, longitude, operatingHours, isActive } = bodyParsed.data;

      try {
        const waterPoint = await prisma.waterPoint.create({
          data: { name, address, latitude, longitude, operatingHours, isActive },
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            operatingHours: true,
            isActive: true,
            createdAt: true,
          },
        });

        return reply.code(201).send({
          waterPoint: {
            ...waterPoint,
            latitude: Number(waterPoint.latitude),
            longitude: Number(waterPoint.longitude),
          },
        });
      } catch (error) {
        request.log.error({ err: error }, 'Failed to create water point');
        return reply.code(500).send({ error: 'Unable to create water point.' });
      }
    }
  );

  // Admin: edit an existing water point.
  fastify.put<{ Params: { id: string }; Body: z.infer<typeof updateWaterPointSchema> }>(
    '/water-points/:id',
    { preHandler: [authenticate, requireAdmin] },
    async (request, reply) => {
      const idParsed = waterPointIdSchema.safeParse(request.params.id);

      if (!idParsed.success) {
        return reply.code(400).send({ error: 'Invalid water point ID.' });
      }

      const bodyParsed = updateWaterPointSchema.safeParse(request.body);

      if (!bodyParsed.success) {
        return reply.code(400).send({
          error: 'Invalid request body.',
          details: bodyParsed.error.flatten().fieldErrors,
        });
      }

      const updateData = Object.fromEntries(
        Object.entries(bodyParsed.data).filter(([, value]) => value !== undefined)
      );

      if (Object.keys(updateData).length === 0) {
        return reply.code(400).send({ error: 'At least one field must be provided.' });
      }

      try {
        const existing = await prisma.waterPoint.findUnique({
          where: { id: idParsed.data },
        });

        if (!existing) {
          return reply.code(404).send({ error: 'Water point not found.' });
        }

        const updated = await prisma.waterPoint.update({
          where: { id: idParsed.data },
          data: updateData,
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            operatingHours: true,
            isActive: true,
            createdAt: true,
          },
        });

        return reply.send({
          waterPoint: {
            ...updated,
            latitude: Number(updated.latitude),
            longitude: Number(updated.longitude),
          },
        });
      } catch (error) {
        request.log.error({ err: error }, 'Failed to update water point');
        return reply.code(500).send({ error: 'Unable to update water point.' });
      }
    }
  );

  // Admin: deactivate a water point.
  fastify.patch<{ Params: { id: string } }>(
    '/water-points/:id/deactivate',
    { preHandler: [authenticate, requireAdmin] },
    async (request, reply) => {
      const idParsed = waterPointIdSchema.safeParse(request.params.id);

      if (!idParsed.success) {
        return reply.code(400).send({ error: 'Invalid water point ID.' });
      }

      try {
        const existing = await prisma.waterPoint.findUnique({
          where: { id: idParsed.data },
        });

        if (!existing) {
          return reply.code(404).send({ error: 'Water point not found.' });
        }

        const updated = await prisma.waterPoint.update({
          where: { id: idParsed.data },
          data: { isActive: false },
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            operatingHours: true,
            isActive: true,
            createdAt: true,
          },
        });

        return reply.send({
          waterPoint: {
            ...updated,
            latitude: Number(updated.latitude),
            longitude: Number(updated.longitude),
          },
        });
      } catch (error) {
        request.log.error({ err: error }, 'Failed to deactivate water point');
        return reply.code(500).send({ error: 'Unable to deactivate water point.' });
      }
    }
  );
};

export default waterPointsRoutes;