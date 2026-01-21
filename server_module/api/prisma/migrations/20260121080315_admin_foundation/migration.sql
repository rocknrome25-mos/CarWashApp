-- CreateEnum
CREATE TYPE "ShiftStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "AuditType" AS ENUM ('BOOKING_MOVE', 'BOOKING_DELETE', 'BOOKING_CHANGE_SERVICE', 'BOOKING_CHANGE_BODYTYPE', 'BOOKING_DISCOUNT', 'BAY_CLOSE', 'BAY_OPEN', 'SHIFT_OPEN', 'SHIFT_CLOSE', 'CLIENT_BLOCK', 'CLIENT_UNBLOCK');

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "adminNote" TEXT,
ADD COLUMN     "finishedAt" TIMESTAMP(3),
ADD COLUMN     "shiftId" TEXT,
ADD COLUMN     "startedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "Client" ADD COLUMN     "blockReason" TEXT,
ADD COLUMN     "blockedAt" TIMESTAMP(3),
ADD COLUMN     "blockedByUserId" TEXT,
ADD COLUMN     "isBlocked" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "gender" DROP NOT NULL;

-- AlterTable
ALTER TABLE "Location" ALTER COLUMN "address" DROP NOT NULL;

-- AlterTable
ALTER TABLE "Shift" ADD COLUMN     "status" "ShiftStatus" NOT NULL DEFAULT 'OPEN',
ALTER COLUMN "openedAt" SET DEFAULT CURRENT_TIMESTAMP;

-- CreateTable
CREATE TABLE "Bay" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "locationId" TEXT NOT NULL,
    "number" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "closedReason" TEXT,
    "closedAt" TIMESTAMP(3),
    "reopenedAt" TIMESTAMP(3),

    CONSTRAINT "Bay_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditEvent" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "type" "AuditType" NOT NULL,
    "locationId" TEXT,
    "userId" TEXT,
    "shiftId" TEXT,
    "bookingId" TEXT,
    "clientId" TEXT,
    "reason" TEXT,
    "payload" JSONB,

    CONSTRAINT "AuditEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Bay_locationId_idx" ON "Bay"("locationId");

-- CreateIndex
CREATE INDEX "Bay_locationId_isActive_idx" ON "Bay"("locationId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "Bay_locationId_number_key" ON "Bay"("locationId", "number");

-- CreateIndex
CREATE INDEX "AuditEvent_type_idx" ON "AuditEvent"("type");

-- CreateIndex
CREATE INDEX "AuditEvent_createdAt_idx" ON "AuditEvent"("createdAt");

-- CreateIndex
CREATE INDEX "AuditEvent_locationId_idx" ON "AuditEvent"("locationId");

-- CreateIndex
CREATE INDEX "AuditEvent_userId_idx" ON "AuditEvent"("userId");

-- CreateIndex
CREATE INDEX "AuditEvent_shiftId_idx" ON "AuditEvent"("shiftId");

-- CreateIndex
CREATE INDEX "AuditEvent_bookingId_idx" ON "AuditEvent"("bookingId");

-- CreateIndex
CREATE INDEX "AuditEvent_clientId_idx" ON "AuditEvent"("clientId");

-- CreateIndex
CREATE INDEX "Booking_locationId_dateTime_idx" ON "Booking"("locationId", "dateTime");

-- CreateIndex
CREATE INDEX "Booking_shiftId_idx" ON "Booking"("shiftId");

-- CreateIndex
CREATE INDEX "Client_isBlocked_idx" ON "Client"("isBlocked");

-- CreateIndex
CREATE INDEX "Shift_status_idx" ON "Shift"("status");

-- CreateIndex
CREATE INDEX "User_isActive_idx" ON "User"("isActive");

-- AddForeignKey
ALTER TABLE "Bay" ADD CONSTRAINT "Bay_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_shiftId_fkey" FOREIGN KEY ("shiftId") REFERENCES "Shift"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditEvent" ADD CONSTRAINT "AuditEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
