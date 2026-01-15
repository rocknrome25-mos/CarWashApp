/*
  Warnings:

  - The values [OTHER] on the enum `PaymentKind` will be removed. If these variants are still used in the database, this will fail.
  - You are about to drop the column `paidAt` on the `Booking` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[bookingId,kind]` on the table `Payment` will be added. If there are existing duplicate values, this will fail.
  - Made the column `method` on table `Payment` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "PaymentKind_new" AS ENUM ('DEPOSIT', 'REMAINING', 'EXTRA', 'REFUND');
ALTER TABLE "public"."Payment" ALTER COLUMN "kind" DROP DEFAULT;
ALTER TABLE "Payment" ALTER COLUMN "kind" TYPE "PaymentKind_new" USING ("kind"::text::"PaymentKind_new");
ALTER TYPE "PaymentKind" RENAME TO "PaymentKind_old";
ALTER TYPE "PaymentKind_new" RENAME TO "PaymentKind";
DROP TYPE "public"."PaymentKind_old";
COMMIT;

-- AlterTable
ALTER TABLE "Booking" DROP COLUMN "paidAt";

-- AlterTable
ALTER TABLE "Payment" ALTER COLUMN "method" SET NOT NULL,
ALTER COLUMN "kind" DROP DEFAULT;

-- CreateIndex
CREATE UNIQUE INDEX "Payment_bookingId_kind_key" ON "Payment"("bookingId", "kind");
