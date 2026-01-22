-- 1) Create Tenant table
CREATE TABLE "Tenant" (
  "id" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "name" TEXT NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT "Tenant_pkey" PRIMARY KEY ("id")
);

-- Create a stable demo tenant (we'll use this id as default/backfill)
INSERT INTO "Tenant" ("id","updatedAt","name","isActive")
VALUES ('demo-tenant', NOW(), 'Demo Tenant', true)
ON CONFLICT ("id") DO NOTHING;

-- 2) Create TenantFeature table
CREATE TABLE "TenantFeature" (
  "id" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "tenantId" TEXT NOT NULL,
  "key" TEXT NOT NULL,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "params" JSONB,
  CONSTRAINT "TenantFeature_pkey" PRIMARY KEY ("id")
);

-- Unique (tenantId, key)
CREATE UNIQUE INDEX "TenantFeature_tenantId_key_key" ON "TenantFeature"("tenantId","key");
CREATE INDEX "TenantFeature_tenantId_idx" ON "TenantFeature"("tenantId");
CREATE INDEX "TenantFeature_key_idx" ON "TenantFeature"("key");
CREATE INDEX "TenantFeature_enabled_idx" ON "TenantFeature"("enabled");

ALTER TABLE "TenantFeature"
ADD CONSTRAINT "TenantFeature_tenantId_fkey"
FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

-- 3) Add tenantId to Location with default so existing rows get filled
ALTER TABLE "Location"
ADD COLUMN "tenantId" TEXT NOT NULL DEFAULT 'demo-tenant';

-- Make sure existing rows are backfilled (safe even if already filled)
UPDATE "Location" SET "tenantId" = 'demo-tenant' WHERE "tenantId" IS NULL;

-- Add FK + index
CREATE INDEX "Location_tenantId_idx" ON "Location"("tenantId");

ALTER TABLE "Location"
ADD CONSTRAINT "Location_tenantId_fkey"
FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
