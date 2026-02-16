// C:\dev\carwash\server_module\api\prisma\seed.ts
import {
  PrismaClient,
  ServiceKind,
  UserRole,
  ServiceLaborCategory,
} from '@prisma/client';

const prisma = new PrismaClient();

type ServiceSeed = {
  name: string;
  priceRub: number;
  durationMin: number;
  kind: ServiceKind; // BASE | ADDON
  laborCategory?: ServiceLaborCategory; // WASH | CHEM
  isActive?: boolean;
  sortOrder?: number;
};

type LocationSeed = {
  name: string;
  address: string;
  colorHex: string;
  baysCount: number;
};

const TENANT_ID = 'demo-tenant';

async function ensureTenantAndFeatures() {
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
    where: { name: loc.name }, // name is unique for Location
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
      create: { locationId, number, isActive: true },
    });
  }
}

async function upsertService(locationId: string, s: ServiceSeed) {
  const isActive = s.isActive ?? true;
  const sortOrder = s.sortOrder ?? 100;

  // default category: WASH
  const laborCategory = s.laborCategory ?? ServiceLaborCategory.WASH;

  // ✅ Service unique is: @@unique([locationId, name])
  return prisma.service.upsert({
    where: {
      locationId_name: {
        locationId,
        name: s.name,
      },
    },
    update: {
      priceRub: s.priceRub,
      durationMin: s.durationMin,
      kind: s.kind,
      isActive,
      sortOrder,
      laborCategory,
    },
    create: {
      locationId,
      name: s.name,
      priceRub: s.priceRub,
      durationMin: s.durationMin,
      kind: s.kind,
      isActive,
      sortOrder,
      laborCategory,
    },
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

async function ensureWasherPayRules(locationId: string) {
  // WASH = 30%
  await prisma.washerPayRule.upsert({
    where: { locationId_category: { locationId, category: ServiceLaborCategory.WASH } },
    update: { percent: 30, isActive: true },
    create: {
      locationId,
      category: ServiceLaborCategory.WASH,
      percent: 30,
      isActive: true,
    },
  });

  // CHEM = 40%
  await prisma.washerPayRule.upsert({
    where: { locationId_category: { locationId, category: ServiceLaborCategory.CHEM } },
    update: { percent: 40, isActive: true },
    create: {
      locationId,
      category: ServiceLaborCategory.CHEM,
      percent: 40,
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

  // 2) Bays
  await ensureBaysForLocation(loc1.id, loc1.baysCount);
  await ensureBaysForLocation(loc2.id, loc2.baysCount);

  // 3) Services — catalogs per location
  const servicesLoc1: ServiceSeed[] = [
    // BASE (мойка)
    {
      name: 'Мойка кузова',
      priceRub: 1200,
      durationMin: 30,
      kind: ServiceKind.BASE,
      sortOrder: 10,
      laborCategory: ServiceLaborCategory.WASH,
    },
    {
      name: 'Комплекс',
      priceRub: 2500,
      durationMin: 60,
      kind: ServiceKind.BASE,
      sortOrder: 20,
      laborCategory: ServiceLaborCategory.WASH,
    },

    // ADDON
    {
      name: 'Воск',
      priceRub: 800,
      durationMin: 15,
      kind: ServiceKind.ADDON,
      sortOrder: 110,
      laborCategory: ServiceLaborCategory.WASH,
    },
    {
      name: 'Коврики',
      priceRub: 300,
      durationMin: 10,
      kind: ServiceKind.ADDON,
      sortOrder: 120,
      laborCategory: ServiceLaborCategory.WASH,
    },
    {
      name: 'Чернение резины',
      priceRub: 400,
      durationMin: 10,
      kind: ServiceKind.ADDON,
      sortOrder: 130,
      laborCategory: ServiceLaborCategory.WASH,
    },
  ];

  const servicesLoc2: ServiceSeed[] = [
    // BASE
    {
      name: 'Мойка кузова',
      priceRub: 1000,
      durationMin: 30,
      kind: ServiceKind.BASE,
      sortOrder: 10,
      laborCategory: ServiceLaborCategory.WASH,
    },
    {
      name: 'Комплекс',
      priceRub: 2300,
      durationMin: 60,
      kind: ServiceKind.BASE,
      sortOrder: 20,
      laborCategory: ServiceLaborCategory.WASH,
    },
    {
      name: 'Салон',
      priceRub: 1500,
      durationMin: 30,
      kind: ServiceKind.BASE,
      sortOrder: 30,
      laborCategory: ServiceLaborCategory.WASH,
    },

    // ADDON
    {
      name: 'Воск',
      priceRub: 700,
      durationMin: 15,
      kind: ServiceKind.ADDON,
      sortOrder: 110,
      laborCategory: ServiceLaborCategory.WASH,
    },
    {
      name: 'Полировка',
      priceRub: 2000,
      durationMin: 30,
      kind: ServiceKind.ADDON,
      sortOrder: 120,
      laborCategory: ServiceLaborCategory.WASH,
    },
  ];

  for (const s of servicesLoc1) await upsertService(loc1.id, s);
  for (const s of servicesLoc2) await upsertService(loc2.id, s);

  // 4) Payout rules (per location): WASH=30%, CHEM=40%
  await ensureWasherPayRules(loc1.id);
  await ensureWasherPayRules(loc2.id);

  // 5) Demo users
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

  // 6) Demo washers (for new washer app testing)
  await upsertUser({
    phone: '+79990000101',
    name: 'Washer 1 Demo',
    role: UserRole.WASHER,
    locationId: loc1.id,
  });

  await upsertUser({
    phone: '+79990000102',
    name: 'Washer 2 Demo',
    role: UserRole.WASHER,
    locationId: loc2.id,
  });

  console.log(
    '✅ Seed done: tenant+features + locations + bays + services + washerPayRules(WASH=30/CHEM=40) + users(admin/owner/washer)',
  );
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
