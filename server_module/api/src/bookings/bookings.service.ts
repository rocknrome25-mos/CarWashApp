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
    // на всякий случай, но после @default(30) в БД почти не нужен
    return typeof durationMin === 'number' && durationMin > 0 ? durationMin : 30;
  }

  // ✅ auto-complete: COMPLETED только если услуга уже закончилась (end < now)
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
    const nowMs = Date.now();
    const graceMs = 30 * 1000;
    if (dt.getTime() < nowMs - graceMs) {
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

    // ✅ Чтобы не пропускать пересечения около полуночи,
    // берём окно пошире вокруг новой записи (±1 день).
    const windowStart = new Date(newStart.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(newEnd.getTime() + 24 * 60 * 60 * 1000);

    const activeNearby = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.ACTIVE,
        dateTime: { gte: windowStart, lte: windowEnd },
      },
      select: {
        id: true,
        carId: true,
        dateTime: true,
        service: { select: { durationMin: true } },
      },
    });

    // 1) Любая активная бронь пересекает интервал? -> слот занят
    const anyOverlap = activeNearby.find((b) => {
      const dur = this._serviceDurationOrDefault(b.service?.durationMin);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, dur);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });
    if (anyOverlap) {
      throw new ConflictException('Selected time slot is already booked');
    }

    // 2) Эта машина пересекается по времени?
    const carOverlap = activeNearby.find((b) => {
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

    // ✅ тут важно взять service.durationMin, чтобы решить “завершено или нет”
    const existing = await this.prisma.booking.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        dateTime: true,
        service: { select: { durationMin: true } },
      },
    });

    if (!existing) throw new NotFoundException('Booking not found');
    if (existing.status === BookingStatus.CANCELED) return existing;

    const dur = this._serviceDurationOrDefault(existing.service?.durationMin);
    const end = this._end(existing.dateTime, dur);
    const now = new Date();

    // ✅ если уже закончилось — это COMPLETED (и отменять нельзя)
    if (end.getTime() <= now.getTime() || existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }

    // ✅ если уже началось (но ещё не закончилось) — тоже отменять нельзя
    if (existing.dateTime.getTime() <= now.getTime()) {
      throw new BadRequestException('Cannot cancel a started booking');
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
