import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus, PaymentKind } from '@prisma/client';

type PayBody = {
  method?: string;
  kind?: 'DEPOSIT' | 'REMAINING' | 'EXTRA' | 'REFUND';
  amountRub?: number;
};

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
    return aStart < bEnd && bStart < aEnd;
  }

  private _serviceDurationOrDefault(durationMin?: number | null) {
    return typeof durationMin === 'number' && durationMin > 0 ? durationMin : 30;
  }

  private _clampInt(n: unknown, def: number, min: number, max: number) {
    const x = typeof n === 'number' ? n : Number(n);
    if (!Number.isFinite(x)) return def;
    const xi = Math.trunc(x);
    return Math.max(min, Math.min(max, xi));
  }

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
        bufferMin: true,
        service: { select: { durationMin: true } },
      },
    });

    const toCompleteIds = candidates
      .filter((b) => {
        const base = this._serviceDurationOrDefault(b.service?.durationMin);
        const total = base + (b.bufferMin ?? 0);
        const end = this._end(b.dateTime, total);
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

  async findAll(includeCanceled: boolean, clientId?: string) {
    await this._housekeeping();

    const where: any = includeCanceled
      ? {}
      : { status: { not: BookingStatus.CANCELED } };

    // ✅ фильтр по клиенту
    if (clientId) where.clientId = clientId;

    return this.prisma.booking.findMany({
      where,
      orderBy: { dateTime: 'asc' },
      include: {
        car: true,
        service: true,
        payments: { orderBy: { paidAt: 'asc' } },
      },
    });
  }

  async create(body: {
    carId: string;
    serviceId: string;
    dateTime: string;
    bayId?: number;
    depositRub?: number;
    bufferMin?: number;
    comment?: string;
    clientId?: string;
  }) {
    await this._housekeeping();

    if (!body || !body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException('carId, serviceId and dateTime are required');
    }

    const clientId = (body.clientId ?? '').trim();
    if (!clientId) throw new BadRequestException('clientId is required');

    const dt = new Date(body.dateTime);
    if (isNaN(dt.getTime())) {
      throw new BadRequestException('dateTime must be ISO string');
    }

    const nowMs = Date.now();
    const graceMs = 30 * 1000;
    if (dt.getTime() < nowMs - graceMs) {
      throw new BadRequestException('Cannot create booking in the past');
    }

    const bayId = this._clampInt(body.bayId, 1, 1, 20);
    const bufferMin = this._clampInt(body.bufferMin, 15, 0, 120);
    const depositRub = this._clampInt(body.depositRub, 500, 0, 1_000_000);
    const comment =
      typeof body.comment === 'string' && body.comment.trim().length > 0
        ? body.comment.trim().slice(0, 500)
        : null;

    // ✅ car должен принадлежать этому clientId
    const car = await this.prisma.car.findUnique({
      where: { id: body.carId },
      select: { id: true, clientId: true },
    });
    if (!car) throw new BadRequestException('Car not found');

    if (car.clientId && car.clientId !== clientId) {
      throw new ForbiddenException('Not your car');
    }

    const service = await this.prisma.service.findUnique({
      where: { id: body.serviceId },
      select: { id: true, durationMin: true },
    });
    if (!service) throw new BadRequestException('Service not found');

    const baseDur = this._serviceDurationOrDefault(service.durationMin);
    const newDurTotal = baseDur + bufferMin;

    const newStart = dt;
    const newEnd = this._end(newStart, newDurTotal);

    const windowStart = new Date(newStart.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(newEnd.getTime() + 24 * 60 * 60 * 1000);

    const busyStatuses = [BookingStatus.ACTIVE, BookingStatus.PENDING_PAYMENT];

    const nearby = await this.prisma.booking.findMany({
      where: {
        status: { in: busyStatuses },
        bayId,
        dateTime: { gte: windowStart, lte: windowEnd },
      },
      select: {
        id: true,
        carId: true,
        dateTime: true,
        status: true,
        paymentDueAt: true,
        bufferMin: true,
        service: { select: { durationMin: true } },
      },
    });

    const now = new Date();
    const relevant = nearby.filter((b) => {
      if (b.status === BookingStatus.PENDING_PAYMENT) {
        if (!b.paymentDueAt) return false;
        return b.paymentDueAt.getTime() > now.getTime();
      }
      return true;
    });

    const anyOverlap = relevant.find((b) => {
      const bBase = this._serviceDurationOrDefault(b.service?.durationMin);
      const bTotal = bBase + (b.bufferMin ?? 0);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, bTotal);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });

    if (anyOverlap) {
      throw new ConflictException('Selected time slot is already booked');
    }

    const carOverlap = relevant.find((b) => {
      if (b.carId !== body.carId) return false;

      const bBase = this._serviceDurationOrDefault(b.service?.durationMin);
      const bTotal = bBase + (b.bufferMin ?? 0);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, bTotal);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });

    if (carOverlap) {
      throw new ConflictException('This car already has a booking at this time');
    }

    const dueAt = new Date(Date.now() + 15 * 60 * 1000);

    return this.prisma.booking.create({
      data: {
        carId: body.carId,
        serviceId: body.serviceId,
        dateTime: dt,
        clientId, // ✅ сохраняем владельца

        bayId,
        bufferMin,
        depositRub,
        comment,

        status: BookingStatus.PENDING_PAYMENT,
        paymentDueAt: dueAt,
      },
      include: {
        car: true,
        service: true,
        payments: { orderBy: { paidAt: 'asc' } },
      },
    });
  }

  private _parsePayKind(raw?: string): PaymentKind {
    const v = (raw ?? 'DEPOSIT').toUpperCase().trim();
    switch (v) {
      case 'DEPOSIT':
        return PaymentKind.DEPOSIT;
      case 'REMAINING':
        return PaymentKind.REMAINING;
      case 'EXTRA':
        return PaymentKind.EXTRA;
      case 'REFUND':
        return PaymentKind.REFUND;
      default:
        throw new BadRequestException('Invalid payment kind');
    }
  }

  async pay(id: string, body?: PayBody) {
    await this._housekeeping();

    const kind = this._parsePayKind(body?.kind);
    const method = (body?.method ?? 'CARD_TEST').trim() || 'CARD_TEST';

    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        service: { select: { priceRub: true } },
        payments: true,
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    const now = new Date();

    if (booking.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }

    if (kind === PaymentKind.DEPOSIT) {
      if (booking.status === BookingStatus.COMPLETED) {
        throw new ConflictException('Booking is completed');
      }
      if (booking.status === BookingStatus.ACTIVE) {
        return this.prisma.booking.findUnique({
          where: { id },
          include: {
            car: true,
            service: true,
            payments: { orderBy: { paidAt: 'asc' } },
          },
        });
      }

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

      if (booking.dateTime.getTime() <= now.getTime()) {
        throw new ConflictException('Booking already started');
      }

      const amountRub = this._clampInt(body?.amountRub, booking.depositRub ?? 0, 0, 1_000_000);

      await this.prisma.payment.create({
        data: {
          bookingId: booking.id,
          amountRub,
          method,
          kind: PaymentKind.DEPOSIT,
          paidAt: now,
        },
      });

      await this.prisma.booking.update({
        where: { id },
        data: {
          status: BookingStatus.ACTIVE,
          paymentDueAt: null,
        },
      });

      return this.prisma.booking.findUnique({
        where: { id },
        include: {
          car: true,
          service: true,
          payments: { orderBy: { paidAt: 'asc' } },
        },
      });
    }

    const amountRub = this._clampInt(body?.amountRub, 0, 0, 1_000_000);

    try {
      await this.prisma.payment.create({
        data: {
          bookingId: booking.id,
          amountRub,
          method,
          kind,
          paidAt: now,
        },
      });
    } catch (e) {
      throw new ConflictException(`Payment kind ${kind} already exists for this booking`);
    }

    return this.prisma.booking.findUnique({
      where: { id },
      include: {
        car: true,
        service: true,
        payments: { orderBy: { paidAt: 'asc' } },
      },
    });
  }

  async cancel(id: string, clientId?: string) {
    await this._housekeeping();

    const existing = await this.prisma.booking.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        dateTime: true,
        paymentDueAt: true,
        bufferMin: true,
        clientId: true,
        service: { select: { durationMin: true } },
      },
    });

    if (!existing) throw new NotFoundException('Booking not found');

    // ✅ запретим отменять чужую запись (если передали clientId)
    if (clientId && existing.clientId && existing.clientId !== clientId) {
      throw new ForbiddenException('Not your booking');
    }

    if (existing.status === BookingStatus.CANCELED) {
      return this.prisma.booking.findUnique({
        where: { id },
        include: { car: true, service: true, payments: true },
      });
    }

    const base = this._serviceDurationOrDefault(existing.service?.durationMin);
    const total = base + (existing.bufferMin ?? 0);

    const end = this._end(existing.dateTime, total);
    const now = new Date();

    if (end.getTime() <= now.getTime() || existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }

    if (existing.dateTime.getTime() <= now.getTime()) {
      throw new BadRequestException('Cannot cancel a started booking');
    }

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
      include: { car: true, service: true, payments: true },
    });
  }
}
