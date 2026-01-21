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
  const existing = await prisma.location.findUnique({ where: { name: loc.name } });

  if (existing) {
    return prisma.location.update({
      where: { id: existing.id },
      data: {
        address: loc.address,
        colorHex: loc.colorHex,
        baysCount: loc.baysCount,
      },
    });
  }

  return prisma.location.create({ data: loc });
}

async function upsertService(s: ServiceSeed) {
  const existing = await prisma.service.findUnique({ where: { name: s.name } });

  if (existing) {
    return prisma.service.update({
      where: { id: existing.id },
      data: { priceRub: s.priceRub, durationMin: s.durationMin },
    });
  }

  return prisma.service.create({ data: s });
}

async function upsertUser(args: {
  phone: string;
  name: string;
  role: UserRole;
  locationId: string;
}) {
  const existing = await prisma.user.findUnique({ where: { phone: args.phone } });

  if (existing) {
    return prisma.user.update({
      where: { id: existing.id },
      data: {
        name: args.name,
        role: args.role,
        locationId: args.locationId,
        isActive: true,
      },
    });
  }

  return prisma.user.create({
    data: {
      phone: args.phone,
      name: args.name,
      role: args.role,
      locationId: args.locationId,
      isActive: true,
    },
  });
}

async function main() {
  // 1) LOCATIONS (2 шт)
  const locations: LocationSeed[] = [
    {
      name: 'Мойка #1',
      address: 'Локация 1 (заменить позже)',
      colorHex: '#2D9CDB', // синий (можно другой)
      baysCount: 2,
    },
    {
      name: 'Мойка #2',
      address: 'Локация 2 (заменить позже)',
      colorHex: '#2DBD6E', // зелёный (можно другой)
      baysCount: 2,
    },
  ];

  const loc1 = await upsertLocation(locations[0]);
  const loc2 = await upsertLocation(locations[1]);

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
  // Owner привяжем к Мойка #1 (можно потом сделать “owner видит все локации” через отдельную модель)
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

  console.log('✅ Seed done: locations(2), services, users');
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
