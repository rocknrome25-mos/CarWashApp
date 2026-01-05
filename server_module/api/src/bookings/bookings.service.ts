import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus } from '@prisma/client';

@Injectable()
export class BookingsService {
  constructor(private prisma: PrismaService) {}

  private _minutesToMs(m: number) {
    return m * 60 * 1000;
  }

  private _end(start: Date, durationMin: number) {
    return new Date(start.getTime() + this._minutesToMs(durationMin));
  }

  private _overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) {
    // [aStart, aEnd) intersects [bStart, bEnd)
    return aStart < bEnd && bStart < aEnd;
  }

  private _serviceDurationOrDefault(durationMin?: number | null) {
    // дефолт, если durationMin не задан в БД
    return typeof durationMin === 'number' && durationMin > 0 ? durationMin : 30;
  }

  // ✅ auto-complete: помечаем COMPLETED только те, которые уже точно закончились (end < now)
  private async _autoCompletePastActive(): Promise<void> {
    const now = new Date();

    const candidates = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.ACTIVE,
        dateTime: { lt: now },
      },
      select: {
        id: true,
        dateTime: true,
        service: { select: { durationMin: true } },
      },
    });

    const toCompleteIds = candidates
      .filter((b) => {
        const dur = this._serviceDurationOrDefault(b.service?.durationMin);
        const end = this._end(b.dateTime, dur);
        return end.getTime() < now.getTime();
      })
      .map((b) => b.id);

    if (toCompleteIds.length === 0) return;

    await this.prisma.booking.updateMany({
      where: { id: { in: toCompleteIds } },
      data: { status: BookingStatus.COMPLETED },
    });
  }

  async findAll(includeCanceled: boolean) {
    await this._autoCompletePastActive();

    const where = includeCanceled
      ? {}
      : { status: { not: BookingStatus.CANCELED } };

    return this.prisma.booking.findMany({
      where,
      orderBy: { dateTime: 'asc' },
      include: { car: true, service: true },
    });
  }

  async create(body: { carId: string; serviceId: string; dateTime: string }) {
    await this._autoCompletePastActive();

    if (!body || !body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException('carId, serviceId and dateTime are required');
    }

    const dt = new Date(body.dateTime);
    if (isNaN(dt.getTime())) {
      throw new BadRequestException('dateTime must be ISO string');
    }

    // запретим создавать в прошлом (с небольшой форой)
    const now = Date.now();
    const graceMs = 30 * 1000;
    if (dt.getTime() < now - graceMs) {
      throw new BadRequestException('Cannot create booking in the past');
    }

    const car = await this.prisma.car.findUnique({ where: { id: body.carId } });
    if (!car) throw new BadRequestException('Car not found');

    const service = await this.prisma.service.findUnique({
      where: { id: body.serviceId },
      select: { id: true, durationMin: true },
    });
    if (!service) throw new BadRequestException('Service not found');

    const newDur = this._serviceDurationOrDefault(service.durationMin);
    const newStart = dt;
    const newEnd = this._end(newStart, newDur);

    // Чтобы проверять пересечения, берём все активные брони “поблизости”.
    // Для простоты: за тот же день (обычно достаточно).
    const startOfDay = new Date(newStart);
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date(newStart);
    endOfDay.setHours(23, 59, 59, 999);

    const activeThatDay = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.ACTIVE,
        dateTime: { gte: startOfDay, lte: endOfDay },
      },
      select: {
        id: true,
        carId: true,
        dateTime: true,
        service: { select: { durationMin: true } },
      },
    });

    // 1) Любая активная бронь пересекает интервал? -> слот занят
    const anyOverlap = activeThatDay.find((b) => {
      const dur = this._serviceDurationOrDefault(b.service?.durationMin);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, dur);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });
    if (anyOverlap) {
      throw new ConflictException('Selected time slot is already booked');
    }

    // 2) Эта машина пересекается по времени? (если завтра добавишь “несколько дорожек”, это останется полезным)
    const carOverlap = activeThatDay.find((b) => {
      if (b.carId !== body.carId) return false;
      const dur = this._serviceDurationOrDefault(b.service?.durationMin);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, dur);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });
    if (carOverlap) {
      throw new ConflictException('This car already has a booking at this time');
    }

    return this.prisma.booking.create({
      data: {
        carId: body.carId,
        serviceId: body.serviceId,
        dateTime: dt,
        status: BookingStatus.ACTIVE,
      },
      include: { car: true, service: true },
    });
  }

  async cancel(id: string) {
    await this._autoCompletePastActive();

    const existing = await this.prisma.booking.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Booking not found');

    if (existing.status === BookingStatus.CANCELED) return existing;

    if (existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }

    if (existing.dateTime.getTime() < Date.now()) {
      throw new BadRequestException('Cannot cancel a past booking');
    }

    return this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: new Date(),
      },
    });
  }
}
