-- CreateEnum
CREATE TYPE "PlannedShiftStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'CANCELED');

-- AlterTable
ALTER TABLE "Shift" ADD COLUMN     "plannedShiftId" TEXT;

-- CreateTable
CREATE TABLE "PlannedShift" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "locationId" TEXT NOT NULL,
    "createdByUserId" TEXT NOT NULL,
    "startAt" TIMESTAMP(3) NOT NULL,
    "endAt" TIMESTAMP(3) NOT NULL,
    "status" "PlannedShiftStatus" NOT NULL DEFAULT 'DRAFT',
    "note" TEXT,

    CONSTRAINT "PlannedShift_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlannedShiftWasher" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "plannedShiftId" TEXT NOT NULL,
    "washerId" TEXT NOT NULL,
    "plannedBayId" INTEGER,
    "note" TEXT,

    CONSTRAINT "PlannedShiftWasher_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PlannedShift_locationId_startAt_idx" ON "PlannedShift"("locationId", "startAt");

-- CreateIndex
CREATE INDEX "PlannedShift_createdByUserId_createdAt_idx" ON "PlannedShift"("createdByUserId", "createdAt");

-- CreateIndex
CREATE INDEX "PlannedShift_status_idx" ON "PlannedShift"("status");

-- CreateIndex
CREATE INDEX "PlannedShiftWasher_plannedShiftId_plannedBayId_idx" ON "PlannedShiftWasher"("plannedShiftId", "plannedBayId");

-- CreateIndex
CREATE INDEX "PlannedShiftWasher_washerId_createdAt_idx" ON "PlannedShiftWasher"("washerId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "PlannedShiftWasher_plannedShiftId_washerId_key" ON "PlannedShiftWasher"("plannedShiftId", "washerId");

-- CreateIndex
CREATE INDEX "Shift_plannedShiftId_idx" ON "Shift"("plannedShiftId");

-- AddForeignKey
ALTER TABLE "Shift" ADD CONSTRAINT "Shift_plannedShiftId_fkey" FOREIGN KEY ("plannedShiftId") REFERENCES "PlannedShift"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlannedShift" ADD CONSTRAINT "PlannedShift_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlannedShift" ADD CONSTRAINT "PlannedShift_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlannedShiftWasher" ADD CONSTRAINT "PlannedShiftWasher_plannedShiftId_fkey" FOREIGN KEY ("plannedShiftId") REFERENCES "PlannedShift"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlannedShiftWasher" ADD CONSTRAINT "PlannedShiftWasher_washerId_fkey" FOREIGN KEY ("washerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
