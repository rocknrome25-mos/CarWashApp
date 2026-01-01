import {
  Injectable,
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus } from '@prisma/client';

function normalizePlate(input: string): string {
  // 1) trim
  // 2) UPPERCASE (единый формат)
  // 3) убрать пробелы и дефисы
  // 4) оставить только буквы/цифры (латиница + кириллица)
  return input
    .trim()
    .toUpperCase()
    .replace(/[\s\-]/g, '')
    .replace(/[^A-Z0-9А-Я0-9]/g, '');
}

function normalizeUpper(input: string): string {
  // общий нормализатор: UPPERCASE + схлопнуть пробелы
  return input.trim().toUpperCase().replace(/\s+/g, ' ');
}

@Injectable()
export class CarsService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.car.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async create(body: {
    makeDisplay: string;
    modelDisplay: string;
    plateDisplay: string;
    year?: number | null;
    color?: string | null;
    bodyType?: string | null;
  }) {
    // FROM NOW ON: хранить display тоже в UPPERCASE
    const makeDisplay = normalizeUpper(body.makeDisplay ?? '');
    const modelDisplay = normalizeUpper(body.modelDisplay ?? '');
    const plateDisplay = normalizePlate(body.plateDisplay ?? '');

    if (!makeDisplay) throw new BadRequestException('makeDisplay is required');
    if (!modelDisplay) throw new BadRequestException('modelDisplay is required');
    if (!plateDisplay) throw new BadRequestException('plateDisplay is required');

    // normalized — тоже UPPERCASE, полностью совпадает по регистру всегда
    const makeNormalized = makeDisplay;
    const modelNormalized = modelDisplay;

    // plateNormalized — строго UPPERCASE единый формат
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
        },
      });
    } catch (e: any) {
      if (e?.code === 'P2002') {
        throw new ConflictException('Car with this plate already exists');
      }
      throw e;
    }
  }

  async remove(id: string) {
    const existing = await this.prisma.car.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Car not found');

    // Если есть ACTIVE бронирования — запретим удаление
    const activeBooking = await this.prisma.booking.findFirst({
      where: { carId: id, status: BookingStatus.ACTIVE },
      select: { id: true },
    });

    if (activeBooking) {
      throw new ConflictException(
        'Cannot delete car with active bookings. Cancel booking first.',
      );
    }

    return this.prisma.car.delete({ where: { id } });
  }
}
