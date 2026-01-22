import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ConfigService {
  constructor(private prisma: PrismaService) {}

  async getConfigByLocationId(locationId: string) {
    const loc = await this.prisma.location.findUnique({
      where: { id: locationId },
      select: {
        id: true,
        name: true,
        tenantId: true,
        tenant: { select: { id: true, name: true, isActive: true } },
      },
    });
    if (!loc) throw new NotFoundException('Location not found');
    if (!loc.tenant.isActive) throw new BadRequestException('Tenant is inactive');

    const features = await this.prisma.tenantFeature.findMany({
      where: { tenantId: loc.tenantId },
      select: { key: true, enabled: true, params: true },
      orderBy: { key: 'asc' },
    });

    const map: Record<string, { enabled: boolean; params: any }> = {};
    for (const f of features) {
      map[f.key] = { enabled: f.enabled, params: f.params ?? null };
    }

    return {
      tenant: loc.tenant,
      location: { id: loc.id, name: loc.name },
      features: map,
    };
  }

  async isEnabledByLocationId(locationId: string, key: string): Promise<boolean> {
    const loc = await this.prisma.location.findUnique({
      where: { id: locationId },
      select: { tenantId: true },
    });
    if (!loc) return false;

    const f = await this.prisma.tenantFeature.findUnique({
      where: { tenantId_key: { tenantId: loc.tenantId, key } },
      select: { enabled: true },
    });
    return f?.enabled ?? false;
  }
}
