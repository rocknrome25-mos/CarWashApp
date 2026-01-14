-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "bayId" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "bufferMin" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "comment" TEXT,
ADD COLUMN     "depositRub" INTEGER NOT NULL DEFAULT 0;

-- CreateIndex
CREATE INDEX "Booking_bayId_idx" ON "Booking"("bayId");
