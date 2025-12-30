import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function upsertService(name: string, priceRub: number) {
  const existing = await prisma.service.findFirst({ where: { name } });

  if (existing) {
    await prisma.service.update({
      where: { id: existing.id },
      data: { priceRub },
    });
    return;
  }

  await prisma.service.create({
    data: { name, priceRub },
  });
}

async function main() {
  await upsertService("Мойка кузова", 1200);
  await upsertService("Комплекс", 2500);
  await upsertService("Воск", 800);

  console.log("✅ Seed done");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
