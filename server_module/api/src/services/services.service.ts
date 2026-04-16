import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma, ServiceKind } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ServicesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(opts: {
    locationId: string;
    kind?: ServiceKind;
    includeInactive?: boolean;
  }) {
    const locationId = (opts.locationId ?? '').trim();
    if (!locationId) {
      throw new BadRequestException('locationId is required');
    }

    const where: Prisma.ServiceWhereInput = {
      locationId,
      ...(opts.kind ? { kind: opts.kind } : {}),
      ...(opts.includeInactive ? {} : { isActive: true }),
    };

    return this.prisma.service.findMany({
      where,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }
}