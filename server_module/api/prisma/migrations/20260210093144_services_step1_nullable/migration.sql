/*
  Warnings:

  - A unique constraint covering the columns `[locationId,name]` on the table `Service` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "ServiceKind" AS ENUM ('BASE', 'ADDON');

-- DropIndex
DROP INDEX "Service_name_key";

-- AlterTable
ALTER TABLE "Service" ADD COLUMN     "isActive" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "kind" "ServiceKind" DEFAULT 'BASE',
ADD COLUMN     "locationId" TEXT,
ADD COLUMN     "sortOrder" INTEGER NOT NULL DEFAULT 100;

-- CreateIndex
CREATE INDEX "Service_locationId_idx" ON "Service"("locationId");

-- CreateIndex
CREATE UNIQUE INDEX "Service_locationId_name_key" ON "Service"("locationId", "name");

-- AddForeignKey
ALTER TABLE "Service" ADD CONSTRAINT "Service_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE CASCADE ON UPDATE CASCADE;
