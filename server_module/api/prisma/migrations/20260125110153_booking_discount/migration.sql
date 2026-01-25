-- AlterTable
ALTER TABLE "Booking" ADD COLUMN     "discountNote" TEXT,
ADD COLUMN     "discountRub" INTEGER NOT NULL DEFAULT 0;
