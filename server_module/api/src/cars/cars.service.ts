import {
  Injectable,
  BadRequestException,
  ConflictException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus } from '@prisma/client';

function normalizePlate(input: string): string {
  return input
    .trim()
    .toUpperCase()
    .replace(/[\s\-]/g, '')
    .replace(/[^A-Z0-9А-Я0-9]/g, '');
}

function normalizeUpper(input: string): string {
  return input.trim().toUpperCase().replace(/\s+/g, ' ');
}

@Injectable()
export class CarsService {
  constructor(private prisma: PrismaService) {}

  async findAll(clientId: string) {
    const cid = (clientId ?? '').trim();
    if (!cid) throw new BadRequestException('clientId is required');

    return this.prisma.car.findMany({
      where: { clientId: cid },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(body: {
    makeDisplay: string;
    modelDisplay: string;
    plateDisplay: string;
    year?: number | null;
    color?: string | null;
    bodyType?: string | null;
    clientId?: string | null;
  }) {
    const makeDisplay = normalizeUpper(body.makeDisplay ?? '');
    const modelDisplay = normalizeUpper(body.modelDisplay ?? '');
    const plateDisplay = normalizePlate(body.plateDisplay ?? '');

    if (!makeDisplay) throw new BadRequestException('makeDisplay is required');
    if (!modelDisplay)
      throw new BadRequestException('modelDisplay is required');
    if (!plateDisplay)
      throw new BadRequestException('plateDisplay is required');

    const clientId = (body.clientId ?? '').trim();
    if (!clientId) throw new BadRequestException('clientId is required');

    const client = await this.prisma.client.findUnique({
      where: { id: clientId },
      select: { id: true },
    });
    if (!client) throw new BadRequestException('Client not found');

    const makeNormalized = makeDisplay;
    const modelNormalized = modelDisplay;
    const plateNormalized = plateDisplay;

    try {
      return await this.prisma.car.create({
        data: {
          makeDisplay,
          modelDisplay,
          plateDisplay,
          makeNormalized,
          modelNormalized,
          plateNormalized,
          year: body.year ?? null,
          color: body.color ? normalizeUpper(body.color) : null,
          bodyType: body.bodyType ? normalizeUpper(body.bodyType) : null,
          clientId,
        },
      });
    } catch (e: any) {
      if (e?.code === 'P2002') {
        throw new ConflictException('Car with this plate already exists');
      }
      throw e;
    }
  }

  async remove(id: string, clientId?: string) {
    const cid = (clientId ?? '').trim(); // clientId может не прийти

    const existing = await this.prisma.car.findUnique({
      where: { id },
      select: { id: true, clientId: true },
    });
    if (!existing) throw new NotFoundException('Car not found');

    // ✅ если clientId передали — проверяем ownership
    if (cid && existing.clientId !== cid) {
      throw new ForbiddenException('Not your car');
    }

    const now = new Date();
    const activeFutureBooking = await this.prisma.booking.findFirst({
      where: {
        carId: id,
        status: BookingStatus.ACTIVE,
        dateTime: { gte: now },
      },
      select: { id: true },
    });

    if (activeFutureBooking) {
      throw new ConflictException(
        'Cannot delete car with active bookings. Cancel booking first.',
      );
    }

    return this.prisma.car.delete({ where: { id } });
  }
}
