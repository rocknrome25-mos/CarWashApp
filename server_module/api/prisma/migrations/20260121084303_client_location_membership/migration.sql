-- CreateTable
CREATE TABLE "ClientLocation" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "clientId" TEXT NOT NULL,
    "locationId" TEXT NOT NULL,
    "isBlocked" BOOLEAN NOT NULL DEFAULT false,
    "blockReason" TEXT,
    "blockedAt" TIMESTAMP(3),
    "blockedByUserId" TEXT,
    "lastVisitAt" TIMESTAMP(3),

    CONSTRAINT "ClientLocation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ClientLocation_locationId_idx" ON "ClientLocation"("locationId");

-- CreateIndex
CREATE INDEX "ClientLocation_clientId_idx" ON "ClientLocation"("clientId");

-- CreateIndex
CREATE INDEX "ClientLocation_locationId_isBlocked_idx" ON "ClientLocation"("locationId", "isBlocked");

-- CreateIndex
CREATE UNIQUE INDEX "ClientLocation_clientId_locationId_key" ON "ClientLocation"("clientId", "locationId");

-- AddForeignKey
ALTER TABLE "ClientLocation" ADD CONSTRAINT "ClientLocation_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "Client"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClientLocation" ADD CONSTRAINT "ClientLocation_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;
