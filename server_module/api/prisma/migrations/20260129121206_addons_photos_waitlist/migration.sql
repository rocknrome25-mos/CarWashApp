/*
  Warnings:

  - Added the required column `updatedAt` to the `BookingAddon` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "Service_name_idx";

-- AlterTable
ALTER TABLE "BookingAddon" ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- AlterTable
ALTER TABLE "BookingPhoto" ALTER COLUMN "kind" DROP DEFAULT;

-- CreateIndex
CREATE INDEX "Service_createdAt_idx" ON "Service"("createdAt");
