import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// Deterministic UUIDs for idempotent seeding (v5 namespace)
const WATER_POINT_UUIDS = {
  'Bole Medhanealem Well': 'aaaaaaaa-bbbb-cccc-dddd-000000000001',
  'Piazza Community Tap': 'aaaaaaaa-bbbb-cccc-dddd-000000000002',
  'Mercato Public Fountain': 'aaaaaaaa-bbbb-cccc-dddd-000000000003',
  'Kazanchis School Well': 'aaaaaaaa-bbbb-cccc-dddd-000000000004',
  'Lideta Market Pump': 'aaaaaaaa-bbbb-cccc-dddd-000000000005',
};

const DEMO_WATER_POINTS = [
  {
    id: WATER_POINT_UUIDS['Bole Medhanealem Well'],
    name: 'Bole Medhanealem Well',
    address: 'Bole Subcity, near Medhanealem Church, Addis Ababa',
    latitude: 8.9867,
    longitude: 38.7993,
    operatingHours: '06:00-22:00',
    isActive: true,
  },
  {
    id: WATER_POINT_UUIDS['Piazza Community Tap'],
    name: 'Piazza Community Tap',
    address: 'Arada Subcity, Piazza District, Addis Ababa',
    latitude: 9.0333,
    longitude: 38.7500,
    operatingHours: '24/7',
    isActive: true,
  },
  {
    id: WATER_POINT_UUIDS['Mercato Public Fountain'],
    name: 'Mercato Public Fountain',
    address: 'Addis Ketema Subcity, Merkato Area, Addis Ababa',
    latitude: 9.0250,
    longitude: 38.7350,
    operatingHours: '05:00-23:00',
    isActive: true,
  },
  {
    id: WATER_POINT_UUIDS['Kazanchis School Well'],
    name: 'Kazanchis School Well',
    address: 'Kirkos Subcity, Kazanchis Near International Community School, Addis Ababa',
    latitude: 9.0100,
    longitude: 38.7650,
    operatingHours: '06:00-20:00',
    isActive: true,
  },
  {
    id: WATER_POINT_UUIDS['Lideta Market Pump'],
    name: 'Lideta Market Pump',
    address: 'Lideta Subcity, Lideta Market, Addis Ababa',
    latitude: 9.0050,
    longitude: 38.7450,
    operatingHours: '07:00-21:00',
    isActive: true,
  },
];

async function main() {
  console.log('Starting database seed...');

  const adminEmail = process.env.ADMIN_EMAIL;
  const adminPassword = process.env.ADMIN_PASSWORD;

  if (!adminEmail || !adminPassword) {
    throw new Error('ADMIN_EMAIL and ADMIN_PASSWORD must be set in environment variables');
  }

  const passwordHash = await bcrypt.hash(adminPassword, 12);

  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {
      passwordHash,
      role: Role.admin,
    },
    create: {
      email: adminEmail,
      passwordHash,
      role: Role.admin,
    },
  });

  console.log(`Admin user ensured: ${admin.email} (${admin.id})`);

  for (const wp of DEMO_WATER_POINTS) {
    const existing = await prisma.waterPoint.findUnique({
      where: { id: wp.id },
    });
    let waterPoint;
    if (existing) {
      waterPoint = await prisma.waterPoint.update({
        where: { id: wp.id },
        data: wp,
      });
    } else {
      waterPoint = await prisma.waterPoint.create({ data: wp });
    }
    console.log(`Water point ensured: ${waterPoint.name} (${waterPoint.id})`);
  }

  console.log('Seed completed successfully.');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });