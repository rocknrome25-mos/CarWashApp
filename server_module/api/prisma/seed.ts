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

const TENANT_ID = 'demo-tenant';

async function ensureTenantAndFeatures() {
  // Tenant.id теперь фиксированный (без cuid), поэтому создаём/обновляем по id
  const tenant = await prisma.tenant.upsert({
    where: { id: TENANT_ID },
    update: { name: 'Demo Tenant', isActive: true },
    create: { id: TENANT_ID, name: 'Demo Tenant', isActive: true },
  });

  const keys = [
    'CASH_DRAWER',
    'BOOKING_MOVE',
    'CONTRACT_PAYMENTS',
    'DISCOUNTS',
    'MEDIA_PHOTOS',
  ];

  for (const key of keys) {
    await prisma.tenantFeature.upsert({
      where: { tenantId_key: { tenantId: tenant.id, key } },
      update: { enabled: true },
      create: { tenantId: tenant.id, key, enabled: true },
    });
  }

  return tenant;
}

async function upsertLocation(tenantId: string, loc: LocationSeed) {
  return prisma.location.upsert({
    where: { name: loc.name }, // name unique
    update: {
      tenantId,
      address: loc.address,
      colorHex: loc.colorHex,
      baysCount: loc.baysCount,
    },
    create: {
      tenantId,
      name: loc.name,
      address: loc.address,
      colorHex: loc.colorHex,
      baysCount: loc.baysCount,
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

async function upsertService(s: ServiceSeed) {
  return prisma.service.upsert({
    where: { name: s.name }, // name unique
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

async function main() {
  // 0) Tenant + Feature flags
  const tenant = await ensureTenantAndFeatures();

  // 1) Locations (2)
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

  const loc1 = await upsertLocation(tenant.id, locations[0]);
  const loc2 = await upsertLocation(tenant.id, locations[1]);

  // 2) Bays (по 2 поста на локацию)
  await ensureBaysForLocation(loc1.id, loc1.baysCount);
  await ensureBaysForLocation(loc2.id, loc2.baysCount);

  // 3) Services
  const services: ServiceSeed[] = [
    { name: 'Мойка кузова', priceRub: 1200, durationMin: 30 },
    { name: 'Комплекс', priceRub: 2500, durationMin: 60 },
    { name: 'Воск', priceRub: 800, durationMin: 15 },
  ];

  for (const s of services) {
    await upsertService(s);
  }

  // 4) Demo users
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

  console.log('✅ Seed done: tenant + features + locations + bays + services + users');
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
