-- AlterEnum
ALTER TYPE "BookingStatus" ADD VALUE 'PENDING_PAYMENT';

-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "cancelReason" TEXT,
ADD COLUMN     "paidAt" TIMESTAMP(3),
ADD COLUMN     "paymentDueAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "Booking_paymentDueAt_idx" ON "Booking"("paymentDueAt");
