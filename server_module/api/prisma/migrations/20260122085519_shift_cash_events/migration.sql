-- CreateEnum
CREATE TYPE "ShiftCashEventType" AS ENUM ('OPEN_FLOAT', 'CASH_IN', 'CASH_OUT', 'CLOSE_COUNT', 'HANDOVER', 'KEEP_IN_DRAWER');

-- CreateTable
CREATE TABLE "ShiftCashEvent" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "shiftId" TEXT NOT NULL,
    "locationId" TEXT NOT NULL,
    "adminId" TEXT NOT NULL,
    "type" "ShiftCashEventType" NOT NULL,
    "amountRub" INTEGER NOT NULL,
    "note" TEXT,

    CONSTRAINT "ShiftCashEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ShiftCashEvent_shiftId_createdAt_idx" ON "ShiftCashEvent"("shiftId", "createdAt");

-- CreateIndex
CREATE INDEX "ShiftCashEvent_locationId_createdAt_idx" ON "ShiftCashEvent"("locationId", "createdAt");

-- CreateIndex
CREATE INDEX "ShiftCashEvent_adminId_createdAt_idx" ON "ShiftCashEvent"("adminId", "createdAt");

-- CreateIndex
CREATE INDEX "ShiftCashEvent_type_idx" ON "ShiftCashEvent"("type");

-- AddForeignKey
ALTER TABLE "ShiftCashEvent" ADD CONSTRAINT "ShiftCashEvent_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "Shift"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShiftCashEvent" ADD CONSTRAINT "ShiftCashEvent_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShiftCashEvent" ADD CONSTRAINT "ShiftCashEvent_adminId_fkey" FOREIGN KEY ("adminId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
