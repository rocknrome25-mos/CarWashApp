import { PrismaClient, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

type ServiceSeed = {
  name: string;
  priceRub: number;
  durationMin: number;
};

type LocationSeed = {
  name: string;
  address: string;
  colorHex: string;
  baysCount: number;
};

async function upsertLocation(loc: LocationSeed) {
  return prisma.location.upsert({
    where: { name: loc.name },
    update: {
      address: loc.address,
      colorHex: loc.colorHex,
      baysCount: loc.baysCount,
    },
    create: loc,
  });
}

async function upsertService(s: ServiceSeed) {
  return prisma.service.upsert({
    where: { name: s.name },
    update: { priceRub: s.priceRub, durationMin: s.durationMin },
    create: s,
  });
}

async function upsertUser(args: {
  phone: string;
  name: string;
  role: UserRole;
  locationId: string;
}) {
  return prisma.user.upsert({
    where: { phone: args.phone },
    update: {
      name: args.name,
      role: args.role,
      locationId: args.locationId,
      isActive: true,
    },
    create: {
      phone: args.phone,
      name: args.name,
      role: args.role,
      locationId: args.locationId,
      isActive: true,
    },
  });
}

async function ensureBaysForLocation(locationId: string, baysCount: number) {
  for (let number = 1; number <= baysCount; number++) {
    await prisma.bay.upsert({
      where: { locationId_number: { locationId, number } },
      update: { isActive: true },
      create: {
        locationId,
        number,
        isActive: true,
      },
    });
  }
}

async function main() {
  // 1) LOCATIONS (2 шт)
  const locations: LocationSeed[] = [
    {
      name: 'Мойка #1',
      address: 'Локация 1 (заменить позже)',
      colorHex: '#2D9CDB',
      baysCount: 2,
    },
    {
      name: 'Мойка #2',
      address: 'Локация 2 (заменить позже)',
      colorHex: '#2DBD6E',
      baysCount: 2,
    },
  ];

  const loc1 = await upsertLocation(locations[0]);
  const loc2 = await upsertLocation(locations[1]);

  // 1.1) BAYS (2 поста на локацию)
  await ensureBaysForLocation(loc1.id, loc1.baysCount);
  await ensureBaysForLocation(loc2.id, loc2.baysCount);

  // 2) SERVICES (с правильными durationMin)
  const services: ServiceSeed[] = [
    { name: 'Мойка кузова', priceRub: 1200, durationMin: 30 },
    { name: 'Комплекс', priceRub: 2500, durationMin: 60 },
    { name: 'Воск', priceRub: 800, durationMin: 15 },
  ];

  for (const s of services) {
    await upsertService(s);
  }

  // 3) DEMO USERS (потом заменим на нормальный auth)
  await upsertUser({
    phone: '+79990000001',
    name: 'Owner Demo',
    role: UserRole.OWNER,
    locationId: loc1.id,
  });

  await upsertUser({
    phone: '+79990000011',
    name: 'Admin 1 Demo',
    role: UserRole.ADMIN,
    locationId: loc1.id,
  });

  await upsertUser({
    phone: '+79990000022',
    name: 'Admin 2 Demo',
    role: UserRole.ADMIN,
    locationId: loc2.id,
  });

  console.log('✅ Seed done: locations(2), bays, services, users');
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
