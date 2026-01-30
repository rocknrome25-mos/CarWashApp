import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import {
  BookingStatus,
  PaymentKind,
  PaymentMethodType,
  Prisma,
  WaitlistStatus,
} from '@prisma/client';
import { BookingsGateway } from './bookings.gateway';

type PayBody = {
  method?: string;
  methodType?: 'CASH' | 'CARD' | 'CONTRACT';
  kind?: 'DEPOSIT' | 'REMAINING' | 'EXTRA' | 'REFUND';
  amountRub?: number;
};

@Injectable()
export class BookingsService {
  private static readonly SLOT_STEP_MIN = 30;
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private prisma: PrismaService,
    private ws: BookingsGateway,
  ) {}

  private _minutesToMs(m: number) {
    return m * 60 * 1000;
  }

  private _roundUpToStepMin(totalMin: number, stepMin: number) {
    if (totalMin <= 0) return 0;
    return Math.ceil(totalMin / stepMin) * stepMin;
  }

  private _end(start: Date, durationMin: number) {
    return new Date(start.getTime() + this._minutesToMs(durationMin));
  }

  private _overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) {
    return aStart < bEnd && bStart < aEnd;
  }

  private _serviceDurationOrDefault(durationMin?: number | null) {
    return typeof durationMin === 'number' && durationMin > 0
      ? durationMin
      : 30;
  }

  private _clampInt(n: unknown, def: number, min: number, max: number) {
    const x = typeof n === 'number' ? n : Number(n);
    if (!Number.isFinite(x)) return def;
    const xi = Math.trunc(x);
    return Math.max(min, Math.min(max, xi));
  }

  // единый include для booking
  private _bookingInclude() {
    return {
      car: true,
      service: true,
      payments: { orderBy: { paidAt: 'asc' as const } },
      location: true,
      addons: { include: { service: true } },
      photos: { orderBy: { createdAt: 'asc' as const } },
    };
  }

  private async _ensureLocationExists(locationId: string): Promise<void> {
    const loc = await this.prisma.location.findUnique({
      where: { id: locationId },
      select: { id: true, baysCount: true },
    });
    if (!loc) throw new BadRequestException('Location not found');
    if (!loc.baysCount || loc.baysCount <= 0) {
      throw new BadRequestException('Location has invalid baysCount');
    }
  }

  private async _getDefaultLocationId(): Promise<string> {
    const loc = await this.prisma.location.findFirst({
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!loc) {
      throw new BadRequestException('No locations configured. Run prisma seed.');
    }
    return loc.id;
  }

  private async _getBayOrThrow(locationId: string, bayNumber: number) {
    const bay = await this.prisma.bay.findUnique({
      where: { locationId_number: { locationId, number: bayNumber } },
      select: { id: true, isActive: true, closedReason: true },
    });
    if (!bay) throw new BadRequestException('Bay not found');
    return bay;
  }

  private async _isAnyBayActive(locationId: string): Promise<boolean> {
    const row = await this.prisma.bay.findFirst({
      where: { locationId, isActive: true },
      select: { id: true },
    });
    return !!row;
  }

  private async _expirePendingPayments(): Promise<void> {
    const now = new Date();

    const expired = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING_PAYMENT,
        paymentDueAt: { not: null, lt: now },
      },
      select: { id: true, locationId: true, bayId: true },
    });

    if (expired.length === 0) return;

    await this.prisma.booking.updateMany({
      where: { id: { in: expired.map((x) => x.id) } },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: now,
        cancelReason: 'PAYMENT_EXPIRED',
      },
    });

    // ✅ WS: чтобы и админ, и клиент обновили списки
    for (const b of expired) {
      this.ws.emitBookingChanged(b.locationId, b.bayId ?? 1);
    }
  }

  private async _autoCompletePastActive(): Promise<void> {
    const now = new Date();

    const candidates = await this.prisma.booking.findMany({
      where: { status: BookingStatus.ACTIVE, dateTime: { lt: now } },
      select: {
        id: true,
        dateTime: true,
        bufferMin: true,
        bayId: true,
        locationId: true,
        service: { select: { durationMin: true } },
      },
    });

    const toComplete = candidates.filter((b) => {
      const base = this._serviceDurationOrDefault(b.service?.durationMin);
      const raw = base + (b.bufferMin ?? 0);
      const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);
      const end = this._end(b.dateTime, total);
      return end.getTime() < now.getTime();
    });

    if (toComplete.length === 0) return;

    await this.prisma.booking.updateMany({
      where: { id: { in: toComplete.map((x) => x.id) } },
      data: { status: BookingStatus.COMPLETED },
    });

    // ✅ WS
    for (const b of toComplete) {
      this.ws.emitBookingChanged(b.locationId, b.bayId ?? 1);
    }
  }

  private async _housekeeping(): Promise<void> {
    await this._expirePendingPayments();
    await this._autoCompletePastActive();
  }

  /**
   * ✅ CRON: статусы меняются даже если никто не дергает API.
   * Каждую минуту: отменяем просроченные оплаты + автозавершаем прошедшие ACTIVE,
   * и шлём WS booking.changed.
   *
   * ВАЖНО: работает только если подключен ScheduleModule.forRoot() в AppModule.
   */
  @Cron('*/1 * * * *') // every minute
  async cronHousekeeping() {
    try {
      await this._housekeeping();
    } catch (e) {
      this.logger.error(`cronHousekeeping failed: ${e}`);
    }
  }

  async getBusySlots(args: {
    locationId: string;
    bayId: number;
    from: Date;
    to: Date;
  }) {
    await this._housekeeping();

    const locationId = (args.locationId ?? '').trim();
    if (!locationId) throw new BadRequestException('locationId is required');
    await this._ensureLocationExists(locationId);

    const bayId = args.bayId;
    const from = args.from;
    const to = args.to;

    const windowStart = new Date(from.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(to.getTime() + 24 * 60 * 60 * 1000);

    const busyStatuses: BookingStatus[] = [
      BookingStatus.ACTIVE,
      BookingStatus.PENDING_PAYMENT,
    ];

    const rows = await this.prisma.booking.findMany({
      where: {
        locationId,
        bayId,
        status: { in: busyStatuses },
        dateTime: { gte: windowStart, lte: windowEnd },
      },
      select: {
        dateTime: true,
        bufferMin: true,
        status: true,
        paymentDueAt: true,
        service: { select: { durationMin: true } },
      },
      orderBy: { dateTime: 'asc' },
    });

    const now = new Date();

    const intervals = rows
      .filter((b) => {
        if (b.status === BookingStatus.ACTIVE) return true;
        if (b.status === BookingStatus.PENDING_PAYMENT) {
          if (!b.paymentDueAt) return false;
          return b.paymentDueAt.getTime() > now.getTime();
        }
        return false;
      })
      .map((b) => {
        const base = this._serviceDurationOrDefault(b.service?.durationMin);
        const raw = base + (b.bufferMin ?? 0);
        const total = this._roundUpToStepMin(
          raw,
          BookingsService.SLOT_STEP_MIN,
        );
        const start = b.dateTime;
        const end = this._end(start, total);
        return { start, end };
      })
      .filter((x) => this._overlaps(x.start, x.end, from, to));

    return intervals.map((x) => ({
      start: x.start.toISOString(),
      end: x.end.toISOString(),
    }));
  }

  async findAll(includeCanceled: boolean, clientId?: string) {
    await this._housekeeping();

    const where: any = includeCanceled
      ? {}
      : { status: { not: BookingStatus.CANCELED } };

    if (clientId) where.clientId = clientId;

    return this.prisma.booking.findMany({
      where,
      orderBy: { dateTime: 'asc' },
      include: this._bookingInclude(),
    });
  }

  async create(body: {
    carId: string;
    serviceId: string;
    dateTime: string;
    locationId?: string;
    bayId?: number;
    depositRub?: number;
    bufferMin?: number;
    comment?: string;
    clientId?: string;
  }) {
    await this._housekeeping();

    if (!body || !body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException(
        'carId, serviceId and dateTime are required',
      );
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

    let locationId = (body.locationId ?? '').trim();
    if (!locationId) locationId = await this._getDefaultLocationId();
    await this._ensureLocationExists(locationId);

    const bayId = this._clampInt(body.bayId, 1, 1, 20);
    const bufferMin = this._clampInt(body.bufferMin, 15, 0, 120);
    const depositRub = this._clampInt(body.depositRub, 500, 0, 1_000_000);

    const comment =
      typeof body.comment === 'string' && body.comment.trim().length > 0
        ? body.comment.trim().slice(0, 500)
        : null;

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

    // ✅ если ВСЕ посты закрыты — всегда waitlist
    const anyBayActive = await this._isAnyBayActive(locationId);
    if (!anyBayActive) {
      await this.prisma.waitlistRequest.create({
        data: {
          status: WaitlistStatus.WAITING,
          locationId,
          desiredDateTime: dt,
          desiredBayId: null,
          clientId,
          carId: body.carId,
          serviceId: body.serviceId,
          comment,
          reason: 'ALL_BAYS_CLOSED',
        },
      });

      this.ws.emitBookingChanged(locationId, 1);
      throw new ConflictException('ALL_BAYS_CLOSED_WAITLISTED');
    }

    // ✅ если выбранный пост закрыт — waitlist
    const bay = await this._getBayOrThrow(locationId, bayId);
    if (bay.isActive !== true) {
      await this.prisma.waitlistRequest.create({
        data: {
          status: WaitlistStatus.WAITING,
          locationId,
          desiredDateTime: dt,
          desiredBayId: bayId,
          clientId,
          carId: body.carId,
          serviceId: body.serviceId,
          comment,
          reason: bay.closedReason ?? 'BAY_CLOSED',
        },
      });

      this.ws.emitBookingChanged(locationId, bayId);
      throw new ConflictException('BAY_CLOSED_WAITLISTED');
    }

    const baseDur = this._serviceDurationOrDefault(service.durationMin);
    const rawDur = baseDur + bufferMin;
    const newDurTotal = this._roundUpToStepMin(
      rawDur,
      BookingsService.SLOT_STEP_MIN,
    );

    const newStart = dt;
    const newEnd = this._end(newStart, newDurTotal);

    const busyStatuses: BookingStatus[] = [
      BookingStatus.ACTIVE,
      BookingStatus.PENDING_PAYMENT,
    ];

    const dueAt = new Date(Date.now() + 10 * 60 * 1000);

    let created: any;

    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        created = await this.prisma.$transaction(
          async (tx) => {
            const now = new Date();

            const cl = await tx.clientLocation.upsert({
              where: { clientId_locationId: { clientId, locationId } },
              update: { lastVisitAt: now },
              create: { clientId, locationId, lastVisitAt: now },
            });

            if (cl.isBlocked) {
              throw new ForbiddenException('You are blocked for this location');
            }

            const windowStart = new Date(
              newStart.getTime() - 24 * 60 * 60 * 1000,
            );
            const windowEnd = new Date(
              newEnd.getTime() + 24 * 60 * 60 * 1000,
            );

            const nearby = await tx.booking.findMany({
              where: {
                locationId,
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

            const relevant = nearby.filter((b) => {
              if (b.status === BookingStatus.PENDING_PAYMENT) {
                if (!b.paymentDueAt) return false;
                return b.paymentDueAt.getTime() > now.getTime();
              }
              return true;
            });

            const anyOverlap = relevant.find((b) => {
              const bBase = this._serviceDurationOrDefault(
                b.service?.durationMin,
              );
              const bRaw = bBase + (b.bufferMin ?? 0);
              const bTotal = this._roundUpToStepMin(
                bRaw,
                BookingsService.SLOT_STEP_MIN,
              );
              const bStart = b.dateTime;
              const bEnd = this._end(bStart, bTotal);
              return this._overlaps(newStart, newEnd, bStart, bEnd);
            });

            if (anyOverlap) {
              throw new ConflictException('Selected time slot is already booked');
            }

            const carNearby = await tx.booking.findMany({
              where: {
                carId: body.carId,
                status: { in: busyStatuses },
                dateTime: { gte: windowStart, lte: windowEnd },
              },
              select: {
                id: true,
                dateTime: true,
                status: true,
                paymentDueAt: true,
                bufferMin: true,
                service: { select: { durationMin: true } },
              },
            });

            const carRelevant = carNearby.filter((b) => {
              if (b.status === BookingStatus.PENDING_PAYMENT) {
                if (!b.paymentDueAt) return false;
                return b.paymentDueAt.getTime() > now.getTime();
              }
              return true;
            });

            const carOverlap = carRelevant.find((b) => {
              const bBase = this._serviceDurationOrDefault(
                b.service?.durationMin,
              );
              const bRaw = bBase + (b.bufferMin ?? 0);
              const bTotal = this._roundUpToStepMin(
                bRaw,
                BookingsService.SLOT_STEP_MIN,
              );
              const bStart = b.dateTime;
              const bEnd = this._end(bStart, bTotal);
              return this._overlaps(newStart, newEnd, bStart, bEnd);
            });

            if (carOverlap) {
              throw new ConflictException(
                'This car already has a booking at this time',
              );
            }

            return tx.booking.create({
              data: {
                carId: body.carId,
                serviceId: body.serviceId,
                dateTime: dt,
                clientId,

                locationId,
                bayId,
                bufferMin,
                depositRub,
                comment,

                status: BookingStatus.PENDING_PAYMENT,
                paymentDueAt: dueAt,
              },
              include: this._bookingInclude(),
            });
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );

        break;
      } catch (e: any) {
        if (e instanceof Prisma.PrismaClientKnownRequestError) {
          if (e.code === 'P2002') {
            throw new ConflictException('Selected time slot is already booked');
          }
          if (e.code === 'P2034') {
            if (attempt < 2) continue;
            throw new ConflictException('Selected time slot is already booked');
          }
        }
        throw e;
      }
    }

    this.ws.emitBookingChanged(locationId, bayId);
    return created;
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

  private _parseMethodType(raw?: string): PaymentMethodType {
    const v = (raw ?? 'CARD').toUpperCase().trim();
    if (v === 'CASH') return PaymentMethodType.CASH;
    if (v === 'CARD') return PaymentMethodType.CARD;
    if (v === 'CONTRACT') return PaymentMethodType.CONTRACT;
    return PaymentMethodType.CARD;
  }

  async pay(id: string, body?: PayBody) {
    await this._housekeeping();

    const kind = this._parsePayKind(body?.kind);
    const method = (body?.method ?? 'CARD').trim() || 'CARD';
    const methodType = this._parseMethodType(body?.methodType ?? body?.method);

    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: { service: { select: { priceRub: true } }, payments: true },
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
          include: this._bookingInclude(),
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

      const amountRub = this._clampInt(
        body?.amountRub,
        booking.depositRub ?? 0,
        0,
        1_000_000,
      );

      await this.prisma.payment.create({
        data: {
          bookingId: booking.id,
          amountRub,
          method,
          methodType,
          kind: PaymentKind.DEPOSIT,
          paidAt: now,
        },
      });

      const updated = await this.prisma.booking.update({
        where: { id },
        data: {
          status: BookingStatus.ACTIVE,
          paymentDueAt: null,
        },
        include: this._bookingInclude(),
      });

      this.ws.emitBookingChanged(updated.locationId, updated.bayId ?? 1);
      return updated;
    }

    const amountRub = this._clampInt(body?.amountRub, 0, 0, 1_000_000);

    try {
      await this.prisma.payment.create({
        data: {
          bookingId: booking.id,
          amountRub,
          method,
          methodType,
          kind,
          paidAt: now,
        },
      });
    } catch {
      throw new ConflictException(
        `Payment kind ${kind} already exists for this booking`,
      );
    }

    const refreshed = await this.prisma.booking.findUnique({
      where: { id },
      include: this._bookingInclude(),
    });

    if (refreshed) {
      this.ws.emitBookingChanged(refreshed.locationId, refreshed.bayId ?? 1);
    }
    return refreshed;
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
        bayId: true,
        locationId: true,
        service: { select: { durationMin: true } },
      },
    });
    if (!existing) throw new NotFoundException('Booking not found');

    if (existing.clientId && existing.clientId !== clientId) {
      throw new ForbiddenException('Not your booking');
    }

    if (existing.status === BookingStatus.CANCELED) {
      return this.prisma.booking.findUnique({
        where: { id },
        include: this._bookingInclude(),
      });
    }

    const base = this._serviceDurationOrDefault(existing.service?.durationMin);
    const raw = base + (existing.bufferMin ?? 0);
    const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);

    const end = this._end(existing.dateTime, total);
    const now = new Date();

    if (
      end.getTime() <= now.getTime() ||
      existing.status === BookingStatus.COMPLETED
    ) {
      throw new ConflictException('Cannot cancel a completed booking');
    }

    if (existing.dateTime.getTime() <= now.getTime()) {
      throw new BadRequestException('Cannot cancel a started booking');
    }

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: now,
        cancelReason:
          existing.status === BookingStatus.PENDING_PAYMENT
            ? 'USER_CANCELED_PENDING'
            : 'USER_CANCELED',
      },
      include: this._bookingInclude(),
    });

    this.ws.emitBookingChanged(updated.locationId, updated.bayId ?? 1);
    return updated;
  }
}
