import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type ServiceSeed = {
  name: string;
  priceRub: number;
  durationMin: number;
};

async function upsertService({
  name,
  priceRub,
  durationMin,
}: ServiceSeed) {
  const existing = await prisma.service.findFirst({
    where: { name },
  });

  if (existing) {
    await prisma.service.update({
      where: { id: existing.id },
      data: {
        priceRub,
        durationMin,
      },
    });
    return;
  }

  await prisma.service.create({
    data: {
      name,
      priceRub,
      durationMin,
    },
  });
}

async function main() {
  const services: ServiceSeed[] = [
    { name: 'Мойка кузова', priceRub: 1200, durationMin: 30 },
    { name: 'Комплекс', priceRub: 2500, durationMin: 60 },
    { name: 'Воск', priceRub: 800, durationMin: 15 },
  ];

  for (const s of services) {
    await upsertService(s);
  }

  console.log('✅ Seed done');
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
