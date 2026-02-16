-- CreateEnum
CREATE TYPE "ServiceLaborCategory" AS ENUM ('WASH', 'CHEM');

-- CreateEnum
CREATE TYPE "WasherClockEventType" AS ENUM ('CLOCK_IN', 'CLOCK_OUT');

-- AlterTable
ALTER TABLE "Service" ADD COLUMN     "laborCategory" "ServiceLaborCategory" NOT NULL DEFAULT 'WASH';

-- CreateTable
CREATE TABLE "WasherPayRule" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "locationId" TEXT NOT NULL,
    "category" "ServiceLaborCategory" NOT NULL,
    "percent" INTEGER NOT NULL DEFAULT 30,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "WasherPayRule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShiftWasher" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "shiftId" TEXT NOT NULL,
    "washerId" TEXT NOT NULL,
    "bayId" INTEGER NOT NULL,
    "percentWash" INTEGER NOT NULL DEFAULT 30,
    "percentChem" INTEGER NOT NULL DEFAULT 40,
    "clockInAt" TIMESTAMP(3),
    "clockOutAt" TIMESTAMP(3),

    CONSTRAINT "ShiftWasher_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WasherClockEvent" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "shiftWasherId" TEXT NOT NULL,
    "type" "WasherClockEventType" NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WasherClockEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "WasherPayRule_locationId_idx" ON "WasherPayRule"("locationId");

-- CreateIndex
CREATE INDEX "WasherPayRule_category_idx" ON "WasherPayRule"("category");

-- CreateIndex
CREATE INDEX "WasherPayRule_isActive_idx" ON "WasherPayRule"("isActive");

-- CreateIndex
CREATE UNIQUE INDEX "WasherPayRule_locationId_category_key" ON "WasherPayRule"("locationId", "category");

-- CreateIndex
CREATE INDEX "ShiftWasher_shiftId_idx" ON "ShiftWasher"("shiftId");

-- CreateIndex
CREATE INDEX "ShiftWasher_washerId_idx" ON "ShiftWasher"("washerId");

-- CreateIndex
CREATE INDEX "ShiftWasher_shiftId_bayId_idx" ON "ShiftWasher"("shiftId", "bayId");

-- CreateIndex
CREATE INDEX "ShiftWasher_clockInAt_idx" ON "ShiftWasher"("clockInAt");

-- CreateIndex
CREATE INDEX "ShiftWasher_clockOutAt_idx" ON "ShiftWasher"("clockOutAt");

-- CreateIndex
CREATE UNIQUE INDEX "ShiftWasher_shiftId_washerId_key" ON "ShiftWasher"("shiftId", "washerId");

-- CreateIndex
CREATE INDEX "WasherClockEvent_shiftWasherId_createdAt_idx" ON "WasherClockEvent"("shiftWasherId", "createdAt");

-- CreateIndex
CREATE INDEX "WasherClockEvent_type_idx" ON "WasherClockEvent"("type");

-- CreateIndex
CREATE INDEX "Service_locationId_laborCategory_idx" ON "Service"("locationId", "laborCategory");

-- AddForeignKey
ALTER TABLE "WasherPayRule" ADD CONSTRAINT "WasherPayRule_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShiftWasher" ADD CONSTRAINT "ShiftWasher_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "Shift"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShiftWasher" ADD CONSTRAINT "ShiftWasher_washerId_fkey" FOREIGN KEY ("washerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WasherClockEvent" ADD CONSTRAINT "WasherClockEvent_shiftWasherId_fkey" FOREIGN KEY ("shiftWasherId") REFERENCES "ShiftWasher"("id") ON DELETE CASCADE ON UPDATE CASCADE;
