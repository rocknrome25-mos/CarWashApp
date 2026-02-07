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
  AuditType,
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

type AddonInput = {
  serviceId: string;
  qty?: number;
};

@Injectable()
export class BookingsService {
  private static readonly SLOT_STEP_MIN = 30;
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private prisma: PrismaService,
    private ws: BookingsGateway,
  ) {}

  /* ===================== helpers ===================== */

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
    return typeof durationMin === 'number' && durationMin > 0 ? durationMin : 30;
  }

  private _clampInt(n: unknown, def: number, min: number, max: number) {
    const x = typeof n === 'number' ? n : Number(n);
    if (!Number.isFinite(x)) return def;
    const xi = Math.trunc(x);
    return Math.max(min, Math.min(max, xi));
  }

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

  private _addonDurSum(
    addons:
      | Array<{ qty: number; durationMinSnapshot: number }>
      | undefined
      | null,
  ): number {
    const list = addons ?? [];
    let sum = 0;
    for (const a of list) {
      const q =
        typeof a.qty === 'number' && Number.isFinite(a.qty) && a.qty > 0
          ? a.qty
          : 1;
      const d =
        typeof a.durationMinSnapshot === 'number' &&
        Number.isFinite(a.durationMinSnapshot) &&
        a.durationMinSnapshot > 0
          ? a.durationMinSnapshot
          : 0;
      sum += q * d;
    }
    return sum;
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

  /* ===================== housekeeping ===================== */

  private async _expirePendingPayments(): Promise<boolean> {
    const now = new Date();

    const expired = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING_PAYMENT,
        paymentDueAt: { not: null, lt: now },
      },
      select: { id: true, locationId: true, bayId: true },
    });

    if (expired.length === 0) return false;

    await this.prisma.booking.updateMany({
      where: { id: { in: expired.map((x) => x.id) } },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: now,
        cancelReason: 'PAYMENT_EXPIRED',
      },
    });

    for (const b of expired) {
      this.ws.emitBookingChanged(b.locationId, b.bayId ?? 1);
    }

    return true;
  }

  private async _autoCompletePastActive(): Promise<boolean> {
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
        addons: { select: { qty: true, durationMinSnapshot: true } },
      },
    });

    const toComplete = candidates.filter((b) => {
      const base = this._serviceDurationOrDefault(b.service?.durationMin);
      const addonSum = this._addonDurSum(b.addons as any);
      const raw = base + addonSum + (b.bufferMin ?? 0);
      const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);
      const end = this._end(b.dateTime, total);
      return end.getTime() < now.getTime();
    });

    if (toComplete.length === 0) return false;

    await this.prisma.booking.updateMany({
      where: { id: { in: toComplete.map((x) => x.id) } },
      data: { status: BookingStatus.COMPLETED },
    });

    for (const b of toComplete) {
      this.ws.emitBookingChanged(b.locationId, b.bayId ?? 1);
    }

    return true;
  }

  private async _housekeeping(): Promise<void> {
    await this._expirePendingPayments();
    await this._autoCompletePastActive();
  }

  /**
   * ✅ CRON: статусы меняются даже если никто не дергает API.
   */
  @Cron('*/1 * * * *')
  async cronHousekeeping() {
    try {
      const changedA = await this._expirePendingPayments();
      const changedB = await this._autoCompletePastActive();
      if (!changedA && !changedB) return;
    } catch (e) {
      this.logger.error(`cronHousekeeping failed: ${e}`);
    }
  }

  /* ===================== WAITLIST (client) ===================== */

  async findWaitlistForClient(clientId: string, includeAll: boolean) {
    const cid = (clientId ?? '').trim();
    if (!cid) throw new BadRequestException('clientId is required');

    const where: any = { clientId: cid };
    if (!includeAll) where.status = WaitlistStatus.WAITING;

    return this.prisma.waitlistRequest.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        location: {
          select: {
            id: true,
            name: true,
            address: true,
            colorHex: true,
            baysCount: true,
          },
        },
        car: true,
        service: true,
      },
    });
  }

  /* ===================== BUSY SLOTS ===================== */

  async getBusySlots(args: { locationId: string; bayId: number; from: Date; to: Date }) {
    await this._housekeeping();

    const locationId = (args.locationId ?? '').trim();
    if (!locationId) throw new BadRequestException('locationId is required');
    await this._ensureLocationExists(locationId);

    const bayId = args.bayId;
    const from = args.from;
    const to = args.to;

    const windowStart = new Date(from.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(to.getTime() + 24 * 60 * 60 * 1000);

    const busyStatuses: BookingStatus[] = [BookingStatus.ACTIVE, BookingStatus.PENDING_PAYMENT];

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
        addons: { select: { qty: true, durationMinSnapshot: true } },
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
        const addonSum = this._addonDurSum(b.addons as any);
        const raw = base + addonSum + (b.bufferMin ?? 0);
        const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);
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

// ✅ CANCEL WAITLIST (client)
async cancelWaitlistRequest(waitlistId: string, clientId: string) {
  await this._housekeeping();

  const wid = (waitlistId ?? '').trim();
  const cid = (clientId ?? '').trim();
  if (!wid) throw new BadRequestException('waitlist id is required');
  if (!cid) throw new BadRequestException('clientId is required');

  const wl = await this.prisma.waitlistRequest.findUnique({
    where: { id: wid },
    select: {
      id: true,
      clientId: true,
      locationId: true,
      status: true,
      desiredBayId: true,
      desiredDateTime: true,
      reason: true,
    },
  });

  if (!wl) throw new NotFoundException('Waitlist request not found');

  if (wl.clientId !== cid) {
    throw new ForbiddenException('Not your waitlist request');
  }

  // already not waiting => idempotent OK
  if (wl.status !== WaitlistStatus.WAITING) {
    return { ok: true, id: wl.id, status: wl.status };
  }

  const updated = await this.prisma.waitlistRequest.update({
    where: { id: wl.id },
    data: {
      status: WaitlistStatus.CANCELED,
      reason: 'CLIENT_CANCELED',
    },
    select: { id: true, status: true, locationId: true, desiredBayId: true },
  });

  // ✅ audit without prisma enum migration: reuse existing BOOKING_DELETE
  await this.prisma.auditEvent.create({
    data: {
      type: AuditType.BOOKING_DELETE,
      locationId: wl.locationId,
      clientId: wl.clientId,
      reason: 'WAITLIST_CLIENT_CANCEL',
      payload: {
        waitlistId: wl.id,
        prevStatus: wl.status,
        newStatus: updated.status,
        desiredBayId: wl.desiredBayId ?? null,
        desiredDateTime: wl.desiredDateTime?.toISOString?.() ?? null,
      },
    },
  });

  // ✅ realtime refresh for both apps
  const bay = wl.desiredBayId ?? 1;
  this.ws.emitBookingChanged(wl.locationId, bay);

  return { ok: true, id: updated.id, status: updated.status };
}


  /* ===================== LIST BOOKINGS ===================== */

  // ✅ return computed payment fields + isWashing
  async findAll(includeCanceled: boolean, clientId?: string) {
    await this._housekeeping();

    const where: any = includeCanceled ? {} : { status: { not: BookingStatus.CANCELED } };
    if (clientId) where.clientId = clientId;

    const rows = await this.prisma.booking.findMany({
      where,
      orderBy: { dateTime: 'asc' },
      include: this._bookingInclude(),
    });

    return rows.map((b: any) => {
      const paidTotalRub = (b.payments ?? []).reduce(
        (s: number, p: any) => s + (p.amountRub ?? 0),
        0,
      );

      const basePriceRub = b.service?.priceRub ?? 0;
      const discountRub = b.discountRub ?? 0;

      const addonsSumRub = (b.addons ?? []).reduce((s: number, a: any) => {
        const qty = a.qty ?? 1;
        return s + (a.priceRubSnapshot ?? 0) * qty;
      }, 0);

      const effectivePriceRub = Math.max(basePriceRub + addonsSumRub - discountRub, 0);
      const remainingRub = Math.max(effectivePriceRub - paidTotalRub, 0);

      const badgeSet = new Set<string>();
      for (const p of b.payments ?? []) {
        badgeSet.add(String(p.methodType ?? 'CARD'));
      }
      const paymentBadges = Array.from(badgeSet);

      let paymentStatus = 'UNPAID';
      if (effectivePriceRub > 0 && paidTotalRub >= effectivePriceRub) {
        paymentStatus = 'PAID';
      } else if (paidTotalRub > 0) {
        paymentStatus = 'PARTIAL';
      }

      const isWashing =
        !!b.startedAt &&
        !b.finishedAt &&
        b.status !== BookingStatus.CANCELED &&
        b.status !== BookingStatus.COMPLETED;

      return {
        ...b,
        isWashing,
        paidTotalRub,
        effectivePriceRub,
        remainingRub,
        paymentBadges,
        paymentStatus,
      };
    });
  }

  /* ===================== CONFLICT CHECK (shared) ===================== */

  private async _checkSlotFree(args: {
    tx: Prisma.TransactionClient;
    bookingIdToExclude?: string;
    locationId: string;
    bayId: number;
    carId: string;
    start: Date;
    durationTotalMin: number;
  }) {
    const { tx, bookingIdToExclude, locationId, bayId, carId, start, durationTotalMin } = args;

    const end = this._end(start, durationTotalMin);
    const windowStart = new Date(start.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(end.getTime() + 24 * 60 * 60 * 1000);

    const busyStatuses: BookingStatus[] = [BookingStatus.ACTIVE, BookingStatus.PENDING_PAYMENT];
    const now = new Date();

    const whereBase: any = {
      locationId,
      bayId,
      status: { in: busyStatuses },
      dateTime: { gte: windowStart, lte: windowEnd },
    };
    if (bookingIdToExclude) whereBase.id = { not: bookingIdToExclude };

    const nearby = await tx.booking.findMany({
      where: whereBase,
      select: {
        id: true,
        dateTime: true,
        status: true,
        paymentDueAt: true,
        bufferMin: true,
        service: { select: { durationMin: true } },
        addons: { select: { qty: true, durationMinSnapshot: true } },
      },
    });

    const relevant = nearby.filter((b) => {
      if (b.status === BookingStatus.PENDING_PAYMENT) {
        if (!b.paymentDueAt) return false;
        return b.paymentDueAt.getTime() > now.getTime();
      }
      return true;
    });

    const overlap = relevant.find((b) => {
      const base = this._serviceDurationOrDefault(b.service?.durationMin);
      const addonSum = this._addonDurSum(b.addons as any);
      const raw = base + addonSum + (b.bufferMin ?? 0);
      const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, total);
      return this._overlaps(start, end, bStart, bEnd);
    });

    if (overlap) throw new ConflictException('Selected time slot is already booked');

    const whereCar: any = {
      carId,
      status: { in: busyStatuses },
      dateTime: { gte: windowStart, lte: windowEnd },
    };
    if (bookingIdToExclude) whereCar.id = { not: bookingIdToExclude };

    const carNearby = await tx.booking.findMany({
      where: whereCar,
      select: {
        id: true,
        dateTime: true,
        status: true,
        paymentDueAt: true,
        bufferMin: true,
        service: { select: { durationMin: true } },
        addons: { select: { qty: true, durationMinSnapshot: true } },
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
      const base = this._serviceDurationOrDefault(b.service?.durationMin);
      const addonSum = this._addonDurSum(b.addons as any);
      const raw = base + addonSum + (b.bufferMin ?? 0);
      const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, total);
      return this._overlaps(start, end, bStart, bEnd);
    });

    if (carOverlap) throw new ConflictException('This car already has a booking at this time');
  }

  /* ===================== CREATE (+ addons) ===================== */

  async create(body: {
    carId: string;
    serviceId: string;
    dateTime: string;
    locationId?: string;
    bayId?: number;
    requestedBayId?: number | null;
    depositRub?: number;
    bufferMin?: number;
    comment?: string;
    clientId?: string;
    addons?: AddonInput[];
  }) {
    await this._housekeeping();

    if (!body || !body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException('carId, serviceId and dateTime are required');
    }

    // ✅ quick visibility: what actually arrives
    this.logger.log(
      `create booking: bayId=${String((body as any).bayId)} requestedBayId=${String((body as any).requestedBayId)}`,
    );

    const clientId = (body.clientId ?? '').trim();
    if (!clientId) throw new BadRequestException('clientId is required');

    const dt = new Date(body.dateTime);
    if (isNaN(dt.getTime())) throw new BadRequestException('dateTime must be ISO string');

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

    // ✅ HARD normalize requestedBayId: ONLY null | 1 | 2
    const hasRequestedKey = Object.prototype.hasOwnProperty.call(body as any, 'requestedBayId');

    let requestedBayId: number | null = null;

    if (hasRequestedKey) {
      const raw = (body as any).requestedBayId;

      if (raw === null || raw === undefined || raw === '') {
        requestedBayId = null; // ANY
      } else {
        const n = Number(raw);
        if (!Number.isFinite(n)) {
          throw new BadRequestException('requestedBayId must be 1 or 2 or null');
        }
        const xi = Math.trunc(n);
        if (xi !== 1 && xi !== 2) {
          throw new BadRequestException('requestedBayId must be 1 or 2 or null');
        }
        requestedBayId = xi;
      }
    } else {
      // no key => treat as ANY
      requestedBayId = null;
    }

    const comment =
      typeof body.comment === 'string' && body.comment.trim().length > 0
        ? body.comment.trim().slice(0, 500)
        : null;

    const car = await this.prisma.car.findUnique({
      where: { id: body.carId },
      select: { id: true, clientId: true },
    });
    if (!car) throw new BadRequestException('Car not found');
    if (car.clientId && car.clientId !== clientId) throw new ForbiddenException('Not your car');

    const service = await this.prisma.service.findUnique({
      where: { id: body.serviceId },
      select: { id: true, durationMin: true },
    });
    if (!service) throw new BadRequestException('Service not found');

    // addons validate + fetch services
    const addonsInput = Array.isArray(body.addons) ? body.addons : [];
    const addonPairs: Array<{ serviceId: string; qty: number }> = [];

    for (const a of addonsInput) {
      const sid = (a?.serviceId ?? '').toString().trim();
      if (!sid) continue;

      const qRaw = (a as any)?.qty;
      const q = qRaw == null ? 1 : Math.trunc(Number(qRaw));
      if (!Number.isFinite(q) || q <= 0) throw new BadRequestException('addons.qty must be > 0');

      addonPairs.push({ serviceId: sid, qty: q });
    }

    const addonServicesById = new Map<string, { id: string; priceRub: number; durationMin: number }>();

    if (addonPairs.length > 0) {
      const uniqueAddonIds = Array.from(new Set(addonPairs.map((x) => x.serviceId)));
      const rows = await this.prisma.service.findMany({
        where: { id: { in: uniqueAddonIds } },
        select: { id: true, priceRub: true, durationMin: true },
      });
      for (const r of rows) addonServicesById.set(r.id, r);

      for (const sid of uniqueAddonIds) {
        if (!addonServicesById.has(sid)) {
          throw new BadRequestException(`Addon service not found: ${sid}`);
        }
      }
    }

    // all bays closed => waitlist
    const anyBayActive = await this._isAnyBayActive(locationId);
    if (!anyBayActive) {
      await this.prisma.waitlistRequest.create({
        data: {
          status: WaitlistStatus.WAITING,
          locationId,
          desiredDateTime: dt,
          desiredBayId: requestedBayId, // ✅ keep requested
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

    // selected bay closed => waitlist
    const bay = await this._getBayOrThrow(locationId, bayId);
    if (bay.isActive !== true) {
      await this.prisma.waitlistRequest.create({
        data: {
          status: WaitlistStatus.WAITING,
          locationId,
          desiredDateTime: dt,
          desiredBayId: requestedBayId, // ✅ strictly what client requested (or null)
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

    // duration = base + addons + buffer => round up to 30
    const baseDur = this._serviceDurationOrDefault(service.durationMin);

    let addonDurSum = 0;
    for (const a of addonPairs) {
      const svc = addonServicesById.get(a.serviceId)!;
      const d = this._serviceDurationOrDefault(svc.durationMin);
      addonDurSum += d * a.qty;
    }

    const rawDur = baseDur + addonDurSum + bufferMin;
    const totalMin = this._roundUpToStepMin(rawDur, BookingsService.SLOT_STEP_MIN);

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

            await this._checkSlotFree({
              tx,
              locationId,
              bayId,
              carId: body.carId,
              start: dt,
              durationTotalMin: totalMin,
            });

            const booking = await tx.booking.create({
              data: {
                carId: body.carId,
                serviceId: body.serviceId,
                dateTime: dt,
                clientId,
                locationId,
                bayId,
                requestedBayId, // ✅ SAVE
                bufferMin,
                depositRub,
                comment,
                status: BookingStatus.PENDING_PAYMENT,
                paymentDueAt: dueAt,
              },
              include: this._bookingInclude(),
            });

            if (addonPairs.length > 0) {
              for (const a of addonPairs) {
                const svc = addonServicesById.get(a.serviceId)!;
                await tx.bookingAddon.upsert({
                  where: {
                    bookingId_serviceId: { bookingId: booking.id, serviceId: svc.id },
                  },
                  update: {
                    qty: { increment: a.qty },
                    priceRubSnapshot: svc.priceRub,
                    durationMinSnapshot: svc.durationMin,
                  },
                  create: {
                    bookingId: booking.id,
                    serviceId: svc.id,
                    qty: a.qty,
                    priceRubSnapshot: svc.priceRub,
                    durationMinSnapshot: svc.durationMin,
                  },
                });
              }

              return tx.booking.findUnique({
                where: { id: booking.id },
                include: this._bookingInclude(),
              });
            }

            return booking;
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );

        break;
      } catch (e: any) {
        if (e instanceof Prisma.PrismaClientKnownRequestError) {
          if (e.code === 'P2002') throw new ConflictException('Selected time slot is already booked');
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

  /* ===================== ADDONS (client) ===================== */

  async addAddonForBooking(bookingId: string, dto: { serviceId: string; qty?: number }) {
    await this._housekeeping();

    const bid = (bookingId ?? '').trim();
    if (!bid) throw new BadRequestException('booking id is required');

    const serviceId = (dto?.serviceId ?? '').toString().trim();
    if (!serviceId) throw new BadRequestException('serviceId is required');

    const qtyRaw = dto?.qty;
    const qtyNum = qtyRaw == null ? 1 : Math.trunc(Number(qtyRaw));
    if (!Number.isFinite(qtyNum) || qtyNum <= 0) {
      throw new BadRequestException('qty must be > 0');
    }

    const booking = await this.prisma.booking.findUnique({
      where: { id: bid },
      include: {
        service: { select: { durationMin: true } },
        addons: { select: { qty: true, durationMinSnapshot: true } },
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status === BookingStatus.CANCELED) throw new ConflictException('Booking is canceled');
    if (booking.status === BookingStatus.COMPLETED) throw new ConflictException('Booking is completed');

    const addonSvc = await this.prisma.service.findUnique({
      where: { id: serviceId },
      select: { id: true, priceRub: true, durationMin: true },
    });
    if (!addonSvc) throw new NotFoundException('Service not found');

    const base = this._serviceDurationOrDefault(booking.service?.durationMin);
    const existingAddonSum = this._addonDurSum(booking.addons as any);
    const addDur = this._serviceDurationOrDefault(addonSvc.durationMin) * qtyNum;

    const raw = base + existingAddonSum + addDur + (booking.bufferMin ?? 0);
    const totalMin = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);

    const updated = await this.prisma.$transaction(async (tx) => {
      await this._checkSlotFree({
        tx,
        bookingIdToExclude: booking.id,
        locationId: booking.locationId,
        bayId: booking.bayId,
        carId: booking.carId,
        start: booking.dateTime,
        durationTotalMin: totalMin,
      });

      await tx.bookingAddon.upsert({
        where: {
          bookingId_serviceId: { bookingId: booking.id, serviceId: addonSvc.id },
        },
        update: {
          qty: { increment: qtyNum },
          priceRubSnapshot: addonSvc.priceRub,
          durationMinSnapshot: addonSvc.durationMin,
        },
        create: {
          bookingId: booking.id,
          serviceId: addonSvc.id,
          qty: qtyNum,
          priceRubSnapshot: addonSvc.priceRub,
          durationMinSnapshot: addonSvc.durationMin,
        },
      });

      return tx.booking.findUnique({
        where: { id: booking.id },
        include: this._bookingInclude(),
      });
    });

    this.ws.emitBookingChanged(booking.locationId, booking.bayId ?? 1);
    return updated;
  }

  async removeAddonForBooking(bookingId: string, serviceId: string) {
    await this._housekeeping();

    const bid = (bookingId ?? '').trim();
    const sid = (serviceId ?? '').trim();
    if (!bid) throw new BadRequestException('booking id is required');
    if (!sid) throw new BadRequestException('serviceId is required');

    const booking = await this.prisma.booking.findUnique({
      where: { id: bid },
      select: { id: true, locationId: true, bayId: true, status: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status === BookingStatus.CANCELED) throw new ConflictException('Booking is canceled');
    if (booking.status === BookingStatus.COMPLETED) throw new ConflictException('Booking is completed');

    await this.prisma.bookingAddon.delete({
      where: { bookingId_serviceId: { bookingId: bid, serviceId: sid } },
    });

    this.ws.emitBookingChanged(booking.locationId, booking.bayId ?? 1);

    return this.prisma.booking.findUnique({
      where: { id: bid },
      include: this._bookingInclude(),
    });
  }

  /* ===================== PAY ===================== */

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

    const bid = (id ?? '').trim();
    if (!bid) throw new BadRequestException('booking id is required');

    const kind = this._parsePayKind(body?.kind);
    const method = (body?.method ?? 'CARD').trim() || 'CARD';
    const methodType = this._parseMethodType(body?.methodType ?? body?.method);

    const booking = await this.prisma.booking.findUnique({
      where: { id: bid },
      include: { service: { select: { priceRub: true } }, payments: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const now = new Date();
    if (booking.status === BookingStatus.CANCELED) throw new ConflictException('Booking is canceled');

    if (kind === PaymentKind.DEPOSIT) {
      if (booking.status === BookingStatus.COMPLETED) throw new ConflictException('Booking is completed');

      if (booking.status === BookingStatus.ACTIVE) {
        return this.prisma.booking.findUnique({
          where: { id: bid },
          include: this._bookingInclude(),
        });
      }

      if (!booking.paymentDueAt || booking.paymentDueAt.getTime() <= now.getTime()) {
        await this.prisma.booking.update({
          where: { id: bid },
          data: { status: BookingStatus.CANCELED, canceledAt: now, cancelReason: 'PAYMENT_EXPIRED' },
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
          methodType,
          kind: PaymentKind.DEPOSIT,
          paidAt: now,
        },
      });

      const updated = await this.prisma.booking.update({
        where: { id: bid },
        data: { status: BookingStatus.ACTIVE, paymentDueAt: null },
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
      throw new ConflictException(`Payment kind ${kind} already exists for this booking`);
    }

    const refreshed = await this.prisma.booking.findUnique({
      where: { id: bid },
      include: this._bookingInclude(),
    });

    if (refreshed) this.ws.emitBookingChanged(refreshed.locationId, refreshed.bayId ?? 1);
    return refreshed;
  }

  /* ===================== CANCEL ===================== */

  async cancel(id: string, clientId?: string) {
    await this._housekeeping();

    const bid = (id ?? '').trim();
    if (!bid) throw new BadRequestException('booking id is required');

    const existing = await this.prisma.booking.findUnique({
      where: { id: bid },
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
        addons: { select: { qty: true, durationMinSnapshot: true } },
      },
    });
    if (!existing) throw new NotFoundException('Booking not found');

    if (existing.clientId && existing.clientId !== clientId) {
      throw new ForbiddenException('Not your booking');
    }

    if (existing.status === BookingStatus.CANCELED) {
      return this.prisma.booking.findUnique({
        where: { id: bid },
        include: this._bookingInclude(),
      });
    }

    const base = this._serviceDurationOrDefault(existing.service?.durationMin);
    const addonSum = this._addonDurSum(existing.addons as any);
    const raw = base + addonSum + (existing.bufferMin ?? 0);
    const total = this._roundUpToStepMin(raw, BookingsService.SLOT_STEP_MIN);

    const end = this._end(existing.dateTime, total);
    const now = new Date();

    if (end.getTime() <= now.getTime() || existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }
    if (existing.dateTime.getTime() <= now.getTime()) {
      throw new BadRequestException('Cannot cancel a started booking');
    }

    const updated = await this.prisma.booking.update({
      where: { id: bid },
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
