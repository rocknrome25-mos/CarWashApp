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
    return typeof durationMin === 'number' && durationMin > 0 ? durationMin : 30;
  }

  // ✅ auto-cancel pending when payment deadline passed
  private async _expirePendingPayments(): Promise<void> {
    const now = new Date();

    await this.prisma.booking.updateMany({
      where: {
        status: BookingStatus.PENDING_PAYMENT,
        paymentDueAt: { not: null, lt: now },
      },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: now,
        cancelReason: 'PAYMENT_EXPIRED',
      },
    });
  }

  // ✅ auto-complete: COMPLETED only if service really ended (end < now)
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

  private async _housekeeping(): Promise<void> {
    await this._expirePendingPayments();
    await this._autoCompletePastActive();
  }

  async findAll(includeCanceled: boolean) {
    await this._housekeeping();

    // includeCanceled=true => show all
    // includeCanceled=false => hide only canceled
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
    await this._housekeeping();

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

    // ✅ окно шире вокруг новой записи (±1 день)
    const windowStart = new Date(newStart.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(newEnd.getTime() + 24 * 60 * 60 * 1000);

    // ✅ слот занят и для ACTIVE, и для PENDING_PAYMENT
    const busyStatuses = [BookingStatus.ACTIVE, BookingStatus.PENDING_PAYMENT];

    const nearby = await this.prisma.booking.findMany({
      where: {
        status: { in: busyStatuses },
        dateTime: { gte: windowStart, lte: windowEnd },
      },
      select: {
        id: true,
        carId: true,
        dateTime: true,
        status: true,
        paymentDueAt: true,
        service: { select: { durationMin: true } },
      },
    });

    // игнорируем просроченные pending (на всякий случай)
    const now = new Date();
    const relevant = nearby.filter((b) => {
      if (b.status === BookingStatus.PENDING_PAYMENT) {
        if (!b.paymentDueAt) return false;
        return b.paymentDueAt.getTime() > now.getTime();
      }
      return true; // ACTIVE
    });

    const anyOverlap = relevant.find((b) => {
      const dur = this._serviceDurationOrDefault(b.service?.durationMin);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, dur);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });

    if (anyOverlap) {
      throw new ConflictException('Selected time slot is already booked');
    }

    const carOverlap = relevant.find((b) => {
      if (b.carId !== body.carId) return false;
      const dur = this._serviceDurationOrDefault(b.service?.durationMin);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, dur);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });

    if (carOverlap) {
      throw new ConflictException('This car already has a booking at this time');
    }

    const dueAt = new Date(Date.now() + 15 * 60 * 1000); // 15 минут на оплату

    return this.prisma.booking.create({
      data: {
        carId: body.carId,
        serviceId: body.serviceId,
        dateTime: dt,
        status: BookingStatus.PENDING_PAYMENT,
        paymentDueAt: dueAt,
      },
      include: { car: true, service: true },
    });
  }

  async pay(id: string, body?: { method?: string }) {
    await this._housekeeping();

    const booking = await this.prisma.booking.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        dateTime: true,
        paymentDueAt: true,
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    const now = new Date();

    if (booking.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }
    if (booking.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Booking is completed');
    }
    if (booking.status === BookingStatus.ACTIVE) {
      // идемпотентность: уже оплачено
      return this.prisma.booking.findUnique({
        where: { id },
        include: { car: true, service: true },
      });
    }

    // PENDING_PAYMENT
    if (!booking.paymentDueAt || booking.paymentDueAt.getTime() <= now.getTime()) {
      await this.prisma.booking.update({
        where: { id },
        data: {
          status: BookingStatus.CANCELED,
          canceledAt: now,
          cancelReason: 'PAYMENT_EXPIRED',
        },
      });
      throw new ConflictException('Payment deadline expired');
    }

    // если уже началось — оплату не принимаем
    if (booking.dateTime.getTime() <= now.getTime()) {
      throw new ConflictException('Booking already started');
    }

    // ✅ тестовая оплата: просто активируем
    // method пока не сохраняем (можно добавить поле paymentMethod позже)
    void body?.method; // чтобы линтер не ругался на неиспользуемый параметр (если включен)
    return this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.ACTIVE,
        paidAt: now,
      },
      include: { car: true, service: true },
    });
  }

  async cancel(id: string) {
    await this._housekeeping();

    const existing = await this.prisma.booking.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        dateTime: true,
        paymentDueAt: true,
        service: { select: { durationMin: true } },
      },
    });

    if (!existing) throw new NotFoundException('Booking not found');
    if (existing.status === BookingStatus.CANCELED) {
      return this.prisma.booking.findUnique({
        where: { id },
        include: { car: true, service: true },
      });
    }

    const dur = this._serviceDurationOrDefault(existing.service?.durationMin);
    const end = this._end(existing.dateTime, dur);
    const now = new Date();

    // уже закончилось -> completed
    if (end.getTime() <= now.getTime() || existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }

    // уже началось (но ещё не закончилось) -> нельзя
    if (existing.dateTime.getTime() <= now.getTime()) {
      throw new BadRequestException('Cannot cancel a started booking');
    }

    // ✅ PENDING_PAYMENT и ACTIVE до старта можно отменять
    return this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: now,
        cancelReason:
          existing.status === BookingStatus.PENDING_PAYMENT
            ? 'USER_CANCELED_PENDING'
            : 'USER_CANCELED',
      },
      include: { car: true, service: true },
    });
  }
}
