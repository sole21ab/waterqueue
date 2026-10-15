import type { FastifyPluginAsync } from 'fastify';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../prisma/client.js';

const registerSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(12).max(72),
});

const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(72),
});

const authRoutes: FastifyPluginAsync = async (fastify) => {
  // Register a new resident account.
  fastify.post('/auth/register', async (request, reply) => {
    const parsed = registerSchema.safeParse(request.body);

    if (!parsed.success) {
      return reply.code(400).send({
        error: 'Invalid email or password. Password must be at least 12 characters.',
      });
    }

    const email = parsed.data.email.toLowerCase();
    const { password } = parsed.data;

    if (Buffer.byteLength(password, 'utf8') > 72) {
      return reply.code(400).send({
        error: 'Password must not exceed 72 bytes.',
      });
    }

    try {
      const existingUser = await prisma.user.findUnique({
        where: { email },
      });

      if (existingUser) {
        return reply.code(409).send({
          error: 'An account with this email already exists.',
        });
      }

      const passwordHash = await bcrypt.hash(password, 12);

      const user = await prisma.user.create({
        data: {
          email,
          passwordHash,
          // Never accept the role from the registration request.
          role: 'resident',
        },
        select: {
          id: true,
          email: true,
          role: true,
          createdAt: true,
        },
      });

      const token = await reply.jwtSign({
        sub: user.id,
        email: user.email,
        role: user.role,
      });

      return reply.code(201).send({ user, token });
    } catch (error) {
      // Handle a duplicate email if two registrations race.
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        error.code === 'P2002'
      ) {
        return reply.code(409).send({
          error: 'An account with this email already exists.',
        });
      }

      request.log.error({ err: error }, 'Registration failed');

      return reply.code(500).send({
        error: 'Unable to register account.',
      });
    }
  });

  // Log in an existing user.
  fastify.post('/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);

    if (!parsed.success) {
      return reply.code(400).send({
        error: 'Invalid email or password.',
      });
    }

    const email = parsed.data.email.toLowerCase();
    const { password } = parsed.data;

    if (Buffer.byteLength(password, 'utf8') > 72) {
      return reply.code(401).send({
        error: 'Invalid email or password.',
      });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { email },
      });

      const passwordMatches = user
        ? await bcrypt.compare(password, user.passwordHash)
        : false;

      if (!user || !passwordMatches) {
        return reply.code(401).send({
          error: 'Invalid email or password.',
        });
      }

      const token = await reply.jwtSign({
        sub: user.id,
        email: user.email,
        role: user.role,
      });

      return reply.send({
        user: {
          id: user.id,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt,
        },
        token,
      });
    } catch (error) {
      request.log.error({ err: error }, 'Login failed');

      return reply.code(500).send({
        error: 'Unable to log in.',
      });
    }
  });

  // Return the profile belonging to the token holder.
  fastify.get('/auth/me', async (request, reply) => {
    try {
      await request.jwtVerify();

      const payload = request.user as { sub?: string };

      if (!payload.sub) {
        return reply.code(401).send({ error: 'Unauthorized.' });
      }

      const user = await prisma.user.findUnique({
        where: { id: payload.sub },
        select: {
          id: true,
          email: true,
          role: true,
          createdAt: true,
        },
      });

      if (!user) {
        return reply.code(401).send({ error: 'Unauthorized.' });
      }

      return reply.send({ user });
    } catch {
      return reply.code(401).send({
        error: 'Missing or invalid authentication token.',
      });
    }
  });
};

export default authRoutes;