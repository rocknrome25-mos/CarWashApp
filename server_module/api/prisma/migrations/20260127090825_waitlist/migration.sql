-- CreateEnum
CREATE TYPE "WaitlistStatus" AS ENUM ('WAITING', 'INVITED', 'CANCELED', 'EXPIRED', 'CONVERTED');

-- CreateTable
CREATE TABLE "WaitlistRequest" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "status" "WaitlistStatus" NOT NULL DEFAULT 'WAITING',
    "locationId" TEXT NOT NULL,
    "desiredDateTime" TIMESTAMP(3) NOT NULL,
    "desiredBayId" INTEGER,
    "clientId" TEXT NOT NULL,
    "carId" TEXT NOT NULL,
    "serviceId" TEXT NOT NULL,
    "comment" TEXT,
    "reason" TEXT,
    "invitedAt" TIMESTAMP(3),

    CONSTRAINT "WaitlistRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "WaitlistRequest_locationId_createdAt_idx" ON "WaitlistRequest"("locationId", "createdAt");

-- CreateIndex
CREATE INDEX "WaitlistRequest_locationId_status_idx" ON "WaitlistRequest"("locationId", "status");

-- CreateIndex
CREATE INDEX "WaitlistRequest_clientId_createdAt_idx" ON "WaitlistRequest"("clientId", "createdAt");

-- CreateIndex
CREATE INDEX "WaitlistRequest_desiredDateTime_idx" ON "WaitlistRequest"("desiredDateTime");

-- AddForeignKey
ALTER TABLE "WaitlistRequest" ADD CONSTRAINT "WaitlistRequest_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WaitlistRequest" ADD CONSTRAINT "WaitlistRequest_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "Client"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WaitlistRequest" ADD CONSTRAINT "WaitlistRequest_carId_fkey" FOREIGN KEY ("carId") REFERENCES "Car"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WaitlistRequest" ADD CONSTRAINT "WaitlistRequest_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE CASCADE ON UPDATE CASCADE;
