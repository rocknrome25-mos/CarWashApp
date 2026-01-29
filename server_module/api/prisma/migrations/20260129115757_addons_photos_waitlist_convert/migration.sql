-- CreateEnum
CREATE TYPE "BookingPhotoKind" AS ENUM ('BEFORE', 'AFTER', 'DAMAGE', 'OTHER');

-- AlterTable
ALTER TABLE "WaitlistRequest" ADD COLUMN     "convertedBookingId" TEXT;

-- CreateTable
CREATE TABLE "BookingAddon" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "bookingId" TEXT NOT NULL,
    "serviceId" TEXT NOT NULL,
    "qty" INTEGER NOT NULL DEFAULT 1,
    "priceRubSnapshot" INTEGER NOT NULL,
    "durationMinSnapshot" INTEGER NOT NULL,
    "note" TEXT,

    CONSTRAINT "BookingAddon_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingPhoto" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "bookingId" TEXT NOT NULL,
    "kind" "BookingPhotoKind" NOT NULL DEFAULT 'BEFORE',
    "url" TEXT NOT NULL,
    "note" TEXT,
    "uploadedByUserId" TEXT,

    CONSTRAINT "BookingPhoto_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "BookingAddon_bookingId_createdAt_idx" ON "BookingAddon"("bookingId", "createdAt");

-- CreateIndex
CREATE INDEX "BookingAddon_serviceId_idx" ON "BookingAddon"("serviceId");

-- CreateIndex
CREATE UNIQUE INDEX "BookingAddon_bookingId_serviceId_key" ON "BookingAddon"("bookingId", "serviceId");

-- CreateIndex
CREATE INDEX "BookingPhoto_bookingId_createdAt_idx" ON "BookingPhoto"("bookingId", "createdAt");

-- CreateIndex
CREATE INDEX "BookingPhoto_uploadedByUserId_idx" ON "BookingPhoto"("uploadedByUserId");

-- CreateIndex
CREATE INDEX "BookingPhoto_kind_idx" ON "BookingPhoto"("kind");

-- CreateIndex
CREATE INDEX "Service_name_idx" ON "Service"("name");

-- CreateIndex
CREATE INDEX "WaitlistRequest_convertedBookingId_idx" ON "WaitlistRequest"("convertedBookingId");

-- AddForeignKey
ALTER TABLE "BookingAddon" ADD CONSTRAINT "BookingAddon_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingAddon" ADD CONSTRAINT "BookingAddon_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingPhoto" ADD CONSTRAINT "BookingPhoto_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingPhoto" ADD CONSTRAINT "BookingPhoto_uploadedByUserId_fkey" FOREIGN KEY ("uploadedByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WaitlistRequest" ADD CONSTRAINT "WaitlistRequest_convertedBookingId_fkey" FOREIGN KEY ("convertedBookingId") REFERENCES "Booking"("id") ON DELETE SET NULL ON UPDATE CASCADE;
