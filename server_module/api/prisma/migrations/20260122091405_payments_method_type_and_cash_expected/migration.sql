-- CreateEnum
CREATE TYPE "PaymentMethodType" AS ENUM ('CASH', 'CARD', 'CONTRACT');

-- AlterTable
ALTER TABLE "Payment" ADD COLUMN     "methodType" "PaymentMethodType" NOT NULL DEFAULT 'CARD';

-- CreateIndex
CREATE INDEX "Payment_methodType_idx" ON "Payment"("methodType");
