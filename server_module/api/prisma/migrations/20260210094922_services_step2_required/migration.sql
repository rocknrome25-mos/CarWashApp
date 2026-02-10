/*
  Warnings:

  - Made the column `kind` on table `Service` required. This step will fail if there are existing NULL values in that column.
  - Made the column `locationId` on table `Service` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "Service" ALTER COLUMN "kind" SET NOT NULL,
ALTER COLUMN "locationId" SET NOT NULL;

-- CreateIndex
CREATE INDEX "Service_locationId_kind_idx" ON "Service"("locationId", "kind");

-- CreateIndex
CREATE INDEX "Service_locationId_isActive_idx" ON "Service"("locationId", "isActive");

-- CreateIndex
CREATE INDEX "Service_locationId_sortOrder_idx" ON "Service"("locationId", "sortOrder");
