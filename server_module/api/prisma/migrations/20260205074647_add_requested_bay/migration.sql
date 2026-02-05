-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "requestedBayId" INTEGER;

-- CreateIndex
CREATE INDEX "Booking_requestedBayId_idx" ON "Booking"("requestedBayId");
