import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  AuditType,
  BookingStatus,
  PaymentKind,
  PaymentMethodType,
  ShiftCashEventType,
  ShiftStatus,
  UserRole,
  Prisma,
} from '@prisma/client';
import { BookingsGateway } from '../bookings/bookings.gateway';
import { ConfigService } from '../config/config.service';

import { AdminLoginDto } from './dto/admin-login.dto';
import { AdminBookingStartDto } from './dto/admin-booking-start.dto';
import { AdminBookingFinishDto } from './dto/admin-booking-finish.dto';
import { AdminBookingMoveDto } from './dto/admin-booking-move.dto';
import { AdminBookingPayDto } from './dto/admin-booking-pay.dto';
import { AdminBookingDiscountDto } from './dto/admin-booking-discount.dto';

import { OpenFloatDto } from './cash/dto/open-float.dto';
import { CashMoveDto } from './cash/dto/cash-move.dto';
import { CloseCashDto } from './cash/dto/close-cash.dto';

import { AdminBayCloseDto } from './dto/admin-bay-close.dto';
import { AdminBayOpenDto } from './dto/admin-bay-open.dto';

const F_CASH = 'CASH_DRAWER';
const F_MOVE = 'BOOKING_MOVE';

@Injectable()
export class AdminService {
  private static readonly SLOT_STEP_MIN = 30;

  constructor(
    private prisma: PrismaService,
    private ws: BookingsGateway,
    private cfg: ConfigService,
  ) {}

  /* ===================== helpers ===================== */

  private _minutesToMs(m: number) {
    return m * 60 * 1000;
  }

  private _roundUpToStepMin(totalMin: number) {
    if (totalMin <= 0) return 0;
    return (
      Math.ceil(totalMin / AdminService.SLOT_STEP_MIN) *
      AdminService.SLOT_STEP_MIN
    );
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

  private _parseIsoOrNow(raw?: string): Date {
    if (!raw) return new Date();
    const d = new Date(raw);
    if (isNaN(d.getTime())) throw new BadRequestException('Invalid ISO date');
    return d;
  }

  private _normNote(raw?: string | null, maxLen = 200) {
    const s = (raw ?? '').trim();
    return s ? s.slice(0, maxLen) : null;
  }

  private _requireAdmin(user: { role: UserRole; isActive: boolean }) {
    if (!user.isActive) throw new ForbiddenException('User is inactive');
    if (user.role !== UserRole.ADMIN)
      throw new ForbiddenException('Not an admin');
  }

  private async _getUserOrThrow(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        role: true,
        isActive: true,
        locationId: true,
        phone: true,
        name: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');
    this._requireAdmin(user);
    return user;
  }

  private async _requireActiveShift(userId: string, shiftId: string) {
    const user = await this._getUserOrThrow(userId);

    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
      select: {
        id: true,
        adminId: true,
        locationId: true,
        status: true,
        openedAt: true,
        closedAt: true,
      },
    });
    if (!shift) throw new NotFoundException('Shift not found');

    if (shift.status !== ShiftStatus.OPEN) {
      throw new ForbiddenException('Shift is not open');
    }
    if (shift.adminId !== user.id) {
      throw new ForbiddenException('Shift does not belong to this admin');
    }
    if (shift.locationId !== user.locationId) {
      throw new ForbiddenException('Shift location mismatch');
    }

    return { user, shift };
  }

  private _parseDayRangeUTC(dateYmd: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateYmd)) {
      throw new BadRequestException('date must be YYYY-MM-DD');
    }
    const from = new Date(`${dateYmd}T00:00:00.000Z`);
    const to = new Date(from.getTime() + 24 * 60 * 60 * 1000);
    return { from, to };
  }

  private async _requireFeature(locationId: string, key: string) {
    const ok = await this.cfg.isEnabledByLocationId(locationId, key);
    if (!ok) throw new ForbiddenException(`Feature disabled: ${key}`);
  }

  /* ===================== auth/shift ===================== */

  async login(dto: AdminLoginDto) {
    const phone = (dto?.phone ?? '').trim();
    if (!phone) throw new BadRequestException('phone is required');

    const user = await this.prisma.user.findUnique({
      where: { phone },
      select: {
        id: true,
        role: true,
        isActive: true,
        locationId: true,
        phone: true,
        name: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');
    this._requireAdmin(user);

    const activeShift = await this.prisma.shift.findFirst({
      where: { adminId: user.id, status: ShiftStatus.OPEN },
      orderBy: { openedAt: 'desc' },
      select: { id: true, openedAt: true },
    });

    return {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        locationId: user.locationId,
      },
      activeShiftId: activeShift?.id ?? null,
      activeShiftOpenedAt: activeShift?.openedAt ?? null,
    };
  }

  async openShift(userId: string) {
    const user = await this._getUserOrThrow(userId);

    const existing = await this.prisma.shift.findFirst({
      where: { adminId: user.id, status: ShiftStatus.OPEN },
      select: { id: true },
    });
    if (existing) throw new ConflictException('Shift already open');

    const now = new Date();

    const shift = await this.prisma.shift.create({
      data: {
        adminId: user.id,
        locationId: user.locationId,
        status: ShiftStatus.OPEN,
        openedAt: now,
      },
      select: {
        id: true,
        openedAt: true,
        locationId: true,
        adminId: true,
        status: true,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.SHIFT_OPEN,
        locationId: user.locationId,
        userId: user.id,
        shiftId: shift.id,
        reason: 'SHIFT_OPEN',
      },
    });

    await this.prisma.user.update({
      where: { id: user.id },
      data: { shiftOpenAt: now, shiftCloseAt: null },
    });

    return shift;
  }

  async closeShift(userId: string, shiftId: string) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    const cashEnabled = await this.cfg.isEnabledByLocationId(
      shift.locationId,
      F_CASH,
    );
    if (cashEnabled) {
      const cashClosed = await this.prisma.shiftCashEvent.findFirst({
        where: { shiftId: shift.id, type: ShiftCashEventType.CLOSE_COUNT },
        select: { id: true },
      });
      if (!cashClosed) {
        throw new ConflictException(
          'Cash close is required before closing shift',
        );
      }
    }

    const now = new Date();

    const updated = await this.prisma.shift.update({
      where: { id: shift.id },
      data: { status: ShiftStatus.CLOSED, closedAt: now },
      select: {
        id: true,
        openedAt: true,
        closedAt: true,
        status: true,
        locationId: true,
        adminId: true,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.SHIFT_CLOSE,
        locationId: user.locationId,
        userId: user.id,
        shiftId: shift.id,
        reason: 'SHIFT_CLOSE',
      },
    });

    await this.prisma.user.update({
      where: { id: user.id },
      data: { shiftCloseAt: now },
    });

    return updated;
  }

  /* ===================== calendar ===================== */

  async getCalendarDay(userId: string, shiftId: string, dateYmd: string) {
    const { shift } = await this._requireActiveShift(userId, shiftId);
    const { from, to } = this._parseDayRangeUTC(dateYmd);

    const rows = await this.prisma.booking.findMany({
      where: { locationId: shift.locationId, dateTime: { gte: from, lt: to } },
      orderBy: [{ bayId: 'asc' }, { dateTime: 'asc' }],
      include: {
        car: true,
        client: { select: { id: true, phone: true, name: true } },
        service: {
          select: { id: true, name: true, durationMin: true, priceRub: true },
        },
        payments: { orderBy: { paidAt: 'asc' } },
      },
    });

    return rows.map((b) => {
      const paidTotal = (b.payments ?? []).reduce(
        (s, p) => s + (p.amountRub ?? 0),
        0,
      );

      const price = b.service?.priceRub ?? 0;
      const discount = b.discountRub ?? 0;
      const effectivePrice = Math.max(price - discount, 0);
      const remaining = Math.max(effectivePrice - paidTotal, 0);

      const badgeSet = new Set<string>();
      for (const p of b.payments ?? []) {
        badgeSet.add(String(p.methodType ?? 'CARD'));
      }
      const paymentBadges = Array.from(badgeSet);

      let paymentStatus = 'UNPAID';
      if (effectivePrice > 0 && paidTotal >= effectivePrice)
        paymentStatus = 'PAID';
      else if (paidTotal > 0) paymentStatus = 'PARTIAL';

      return {
        id: b.id,
        dateTime: b.dateTime,
        bayId: b.bayId,
        bufferMin: b.bufferMin,
        comment: b.comment,
        adminNote: b.adminNote,
        startedAt: b.startedAt,
        finishedAt: b.finishedAt,
        status: b.status,
        canceledAt: b.canceledAt,
        cancelReason: b.cancelReason,
        clientId: b.clientId,

        car: {
          id: b.car.id,
          plateDisplay: b.car.plateDisplay,
          makeDisplay: b.car.makeDisplay,
          modelDisplay: b.car.modelDisplay,
          color: b.car.color,
          bodyType: b.car.bodyType,
        },
        client: b.client,
        service: b.service,

        discountRub: b.discountRub ?? 0,
        discountNote: b.discountNote ?? null,
        effectivePriceRub: effectivePrice,

        paymentBadges,
        paymentStatus,
        paidTotalRub: paidTotal,
        remainingRub: remaining,
      };
    });
  }

  /* ===================== bookings: start/move/finish ===================== */

  async startBooking(
    userId: string,
    shiftId: string,
    bookingId: string,
    dto?: AdminBookingStartDto,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    const startedAt = this._parseIsoOrNow(dto?.startedAt);
    const note = this._normNote(dto?.adminNote, 500);

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        locationId: true,
        status: true,
        startedAt: true,
        bayId: true,
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.locationId !== shift.locationId) {
      throw new ForbiddenException('Not your location booking');
    }
    if (booking.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }

    // ✅ BLOCK START IF BAY IS CLOSED
    const bayNumber = booking.bayId ?? 1;
    const bay = await this.prisma.bay.findUnique({
      where: {
        locationId_number: { locationId: shift.locationId, number: bayNumber },
      },
      select: { isActive: true },
    });
    if (!bay) throw new NotFoundException('Bay not found');
    if (bay.isActive !== true) {
      // 409 -> UI покажет "Нужно открыть пост"
      throw new ConflictException('Bay is closed');
    }

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        shiftId: shift.id,
        startedAt: booking.startedAt ?? startedAt,
        adminNote: note ?? undefined,
        status:
          booking.status === BookingStatus.PENDING_PAYMENT
            ? BookingStatus.ACTIVE
            : booking.status,
      },
      select: {
        id: true,
        status: true,
        startedAt: true,
        finishedAt: true,
        adminNote: true,
        shiftId: true,
        locationId: true,
        bayId: true,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.BOOKING_START,
        locationId: user.locationId,
        userId: user.id,
        shiftId: shift.id,
        bookingId: updated.id,
        reason: 'BOOKING_START',
      },
    });

    this.ws.emitBookingChanged(updated.locationId, updated.bayId ?? 1);
    return updated;
  }

  private async _checkMoveConflicts(args: {
    tx: Prisma.TransactionClient;
    bookingId: string;
    locationId: string;
    bayId: number;
    carId: string;
    newStart: Date;
    durationTotalMin: number;
  }) {
    const {
      tx,
      bookingId,
      locationId,
      bayId,
      carId,
      newStart,
      durationTotalMin,
    } = args;

    const newEnd = this._end(newStart, durationTotalMin);
    const windowStart = new Date(newStart.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(newEnd.getTime() + 24 * 60 * 60 * 1000);

    const busyStatuses: BookingStatus[] = [
      BookingStatus.ACTIVE,
      BookingStatus.PENDING_PAYMENT,
    ];
    const now = new Date();

    const nearby = await tx.booking.findMany({
      where: {
        id: { not: bookingId },
        locationId,
        bayId,
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

    const relevant = nearby.filter((b) => {
      if (b.status === BookingStatus.PENDING_PAYMENT) {
        if (!b.paymentDueAt) return false;
        return b.paymentDueAt.getTime() > now.getTime();
      }
      return true;
    });

    const anyOverlap = relevant.find((b) => {
      const base = this._serviceDurationOrDefault(b.service?.durationMin);
      const raw = base + (b.bufferMin ?? 0);
      const total = this._roundUpToStepMin(raw);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, total);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });
    if (anyOverlap) {
      throw new ConflictException('Selected time slot is already booked');
    }

    const carNearby = await tx.booking.findMany({
      where: {
        id: { not: bookingId },
        carId,
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
      const base = this._serviceDurationOrDefault(b.service?.durationMin);
      const raw = base + (b.bufferMin ?? 0);
      const total = this._roundUpToStepMin(raw);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, total);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });
    if (carOverlap) {
      throw new ConflictException('This car already has a booking at this time');
    }
  }

  async moveBooking(
    userId: string,
    shiftId: string,
    bookingId: string,
    dto?: AdminBookingMoveDto,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    await this._requireFeature(shift.locationId, F_MOVE);

    const newDateTimeRaw = (dto?.newDateTime ?? '').trim();
    if (!newDateTimeRaw)
      throw new BadRequestException('newDateTime is required');
    const newDateTime = new Date(newDateTimeRaw);
    if (isNaN(newDateTime.getTime()))
      throw new BadRequestException('newDateTime must be ISO');

    const reason = (dto?.reason ?? '').trim();
    if (!reason) throw new BadRequestException('reason is required');

    if (dto?.clientAgreed !== true)
      throw new BadRequestException('clientAgreed must be true');

    const newBayId =
      typeof dto?.newBayId === 'number' && Number.isFinite(dto.newBayId)
        ? Math.trunc(dto.newBayId)
        : null;

    const existing = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        locationId: true,
        bayId: true,
        dateTime: true,
        status: true,
        clientId: true,
        carId: true,
        bufferMin: true,
        service: { select: { durationMin: true } },
      },
    });
    if (!existing) throw new NotFoundException('Booking not found');
    if (existing.locationId !== shift.locationId) {
      throw new ForbiddenException('Not your location booking');
    }
    if (existing.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }
    if (existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot move a completed booking');
    }

    const oldValue = {
      dateTime: existing.dateTime.toISOString(),
      bayId: existing.bayId,
    };
    const nextBayId = newBayId ?? existing.bayId;

    const baseDur = this._serviceDurationOrDefault(
      existing.service?.durationMin,
    );
    const rawDur = baseDur + (existing.bufferMin ?? 0);
    const durTotal = this._roundUpToStepMin(rawDur);

    const updated = await this.prisma.$transaction(async (tx) => {
      await this._checkMoveConflicts({
        tx,
        bookingId: existing.id,
        locationId: shift.locationId,
        bayId: nextBayId,
        carId: existing.carId,
        newStart: newDateTime,
        durationTotalMin: durTotal,
      });

      const u = await tx.booking.update({
        where: { id: existing.id },
        data: { shiftId: shift.id, dateTime: newDateTime, bayId: nextBayId },
        select: {
          id: true,
          dateTime: true,
          bayId: true,
          locationId: true,
          shiftId: true,
          status: true,
        },
      });

      await tx.auditEvent.create({
        data: {
          type: AuditType.BOOKING_MOVE,
          locationId: user.locationId,
          userId: user.id,
          shiftId: shift.id,
          bookingId: existing.id,
          clientId: existing.clientId ?? undefined,
          reason,
          payload: {
            clientAgreed: true,
            oldValue,
            newValue: { dateTime: u.dateTime.toISOString(), bayId: u.bayId },
          },
        },
      });

      return u;
    });

    this.ws.emitBookingChanged(updated.locationId, oldValue.bayId);
    if (updated.bayId !== oldValue.bayId) {
      this.ws.emitBookingChanged(updated.locationId, updated.bayId);
    }

    return updated;
  }

  async finishBooking(
    userId: string,
    shiftId: string,
    bookingId: string,
    dto?: AdminBookingFinishDto,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    const finishedAt = this._parseIsoOrNow(dto?.finishedAt);
    const note = this._normNote(dto?.adminNote, 500);

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        locationId: true,
        status: true,
        startedAt: true,
        finishedAt: true,
        bayId: true,
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.locationId !== shift.locationId) {
      throw new ForbiddenException('Not your location booking');
    }
    if (booking.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        shiftId: shift.id,
        startedAt: booking.startedAt ?? new Date(),
        finishedAt: booking.finishedAt ?? finishedAt,
        adminNote: note ?? undefined,
        status: BookingStatus.COMPLETED,
      },
      select: {
        id: true,
        status: true,
        startedAt: true,
        finishedAt: true,
        adminNote: true,
        shiftId: true,
        locationId: true,
        bayId: true,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.BOOKING_FINISH,
        locationId: user.locationId,
        userId: user.id,
        shiftId: shift.id,
        bookingId: updated.id,
        reason: 'BOOKING_FINISH',
      },
    });

    this.ws.emitBookingChanged(updated.locationId, updated.bayId ?? 1);
    return updated;
  }

  /* ===================== CASH ===================== */

  private async _cashCreate(
    userId: string,
    shiftId: string,
    type: ShiftCashEventType,
    amountRub: number,
    note?: string | null,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);
    await this._requireFeature(shift.locationId, F_CASH);

    const amount = Number(amountRub);
    if (!Number.isFinite(amount) || amount < 0) {
      throw new BadRequestException('amountRub must be non-negative');
    }

    return this.prisma.shiftCashEvent.create({
      data: {
        shiftId: shift.id,
        locationId: shift.locationId,
        adminId: user.id,
        type,
        amountRub: Math.trunc(amount),
        note: this._normNote(note),
      },
      select: {
        id: true,
        createdAt: true,
        type: true,
        amountRub: true,
        note: true,
      },
    });
  }

  async cashOpenFloat(userId: string, shiftId: string, dto: OpenFloatDto) {
    const { shift } = await this._requireActiveShift(userId, shiftId);
    await this._requireFeature(shift.locationId, F_CASH);

    const exists = await this.prisma.shiftCashEvent.findFirst({
      where: { shiftId: shift.id, type: ShiftCashEventType.OPEN_FLOAT },
      select: { id: true },
    });
    if (exists)
      throw new ConflictException('OPEN_FLOAT already exists for this shift');

    return this._cashCreate(
      userId,
      shiftId,
      ShiftCashEventType.OPEN_FLOAT,
      dto.amountRub,
      dto.note,
    );
  }

  async cashIn(userId: string, shiftId: string, dto: CashMoveDto) {
    if (!dto.note || !dto.note.trim())
      throw new BadRequestException('note is required');
    return this._cashCreate(
      userId,
      shiftId,
      ShiftCashEventType.CASH_IN,
      dto.amountRub,
      dto.note,
    );
  }

  async cashOut(userId: string, shiftId: string, dto: CashMoveDto) {
    if (!dto.note || !dto.note.trim())
      throw new BadRequestException('note is required');
    return this._cashCreate(
      userId,
      shiftId,
      ShiftCashEventType.CASH_OUT,
      dto.amountRub,
      dto.note,
    );
  }

  async cashClose(userId: string, shiftId: string, dto: CloseCashDto) {
    const { shift } = await this._requireActiveShift(userId, shiftId);
    await this._requireFeature(shift.locationId, F_CASH);

    if (dto.handoverRub + dto.keepRub !== dto.countedRub) {
      throw new BadRequestException(
        'handoverRub + keepRub must equal countedRub',
      );
    }

    const exists = await this.prisma.shiftCashEvent.findFirst({
      where: { shiftId: shift.id, type: ShiftCashEventType.CLOSE_COUNT },
      select: { id: true },
    });
    if (exists)
      throw new ConflictException('CLOSE_COUNT already exists for this shift');

    const note = this._normNote(dto.note);

    await this.prisma.$transaction(async (tx) => {
      await tx.shiftCashEvent.create({
        data: {
          shiftId: shift.id,
          locationId: shift.locationId,
          adminId: shift.adminId,
          type: ShiftCashEventType.CLOSE_COUNT,
          amountRub: Math.trunc(dto.countedRub),
          note,
        },
      });
      await tx.shiftCashEvent.create({
        data: {
          shiftId: shift.id,
          locationId: shift.locationId,
          adminId: shift.adminId,
          type: ShiftCashEventType.HANDOVER,
          amountRub: Math.trunc(dto.handoverRub),
          note,
        },
      });
      await tx.shiftCashEvent.create({
        data: {
          shiftId: shift.id,
          locationId: shift.locationId,
          adminId: shift.adminId,
          type: ShiftCashEventType.KEEP_IN_DRAWER,
          amountRub: Math.trunc(dto.keepRub),
          note,
        },
      });
    });

    return { ok: true };
  }

  async cashExpected(userId: string, shiftId: string) {
    const { shift } = await this._requireActiveShift(userId, shiftId);
    await this._requireFeature(shift.locationId, F_CASH);

    const openFloatAgg = await this.prisma.shiftCashEvent.aggregate({
      where: { shiftId: shift.id, type: ShiftCashEventType.OPEN_FLOAT },
      _sum: { amountRub: true },
    });
    const cashInAgg = await this.prisma.shiftCashEvent.aggregate({
      where: { shiftId: shift.id, type: ShiftCashEventType.CASH_IN },
      _sum: { amountRub: true },
    });
    const cashOutAgg = await this.prisma.shiftCashEvent.aggregate({
      where: { shiftId: shift.id, type: ShiftCashEventType.CASH_OUT },
      _sum: { amountRub: true },
    });

    const cashPaidAgg = await this.prisma.payment.aggregate({
      where: {
        booking: { shiftId: shift.id },
        methodType: PaymentMethodType.CASH,
        kind: {
          in: [PaymentKind.DEPOSIT, PaymentKind.REMAINING, PaymentKind.EXTRA],
        },
      },
      _sum: { amountRub: true },
    });

    const cashRefundAgg = await this.prisma.payment.aggregate({
      where: {
        booking: { shiftId: shift.id },
        methodType: PaymentMethodType.CASH,
        kind: PaymentKind.REFUND,
      },
      _sum: { amountRub: true },
    });

    const openFloat = openFloatAgg._sum.amountRub ?? 0;
    const cashIn = cashInAgg._sum.amountRub ?? 0;
    const cashOut = cashOutAgg._sum.amountRub ?? 0;
    const cashPaid = cashPaidAgg._sum.amountRub ?? 0;
    const cashRefund = cashRefundAgg._sum.amountRub ?? 0;

    const expectedRub = openFloat + cashIn - cashOut + cashPaid - cashRefund;

    return {
      shiftId: shift.id,
      expectedRub,
      breakdown: { openFloat, cashIn, cashOut, cashPaid, cashRefund },
    };
  }

  /* ===================== ADMIN PAY ===================== */

  private _parseMethodType(raw: string): PaymentMethodType {
    const v = (raw ?? 'CARD').toUpperCase().trim();
    if (v === 'CASH') return PaymentMethodType.CASH;
    if (v === 'CARD') return PaymentMethodType.CARD;
    if (v === 'CONTRACT') return PaymentMethodType.CONTRACT;
    return PaymentMethodType.CARD;
  }

  async payBookingAdmin(
    userId: string,
    shiftId: string,
    bookingId: string,
    dto: AdminBookingPayDto,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    const methodType = this._parseMethodType(dto.methodType);

    if (methodType === PaymentMethodType.CASH) {
      await this._requireFeature(shift.locationId, 'CASH_DRAWER');
    }
    if (methodType === PaymentMethodType.CONTRACT) {
      await this._requireFeature(shift.locationId, 'CONTRACT_PAYMENTS');
    }

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        service: { select: { priceRub: true } },
        payments: true,
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.locationId !== shift.locationId) {
      throw new ForbiddenException('Not your location booking');
    }
    if (booking.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }

    const amountRub = Math.trunc(Number(dto.amountRub));
    if (!Number.isFinite(amountRub) || amountRub < 0) {
      throw new BadRequestException('amountRub must be non-negative number');
    }

    const kind = (dto.kind ?? 'REMAINING').toUpperCase().trim() as PaymentKind;
    const methodLabel = (dto.methodLabel ?? '').trim() || String(methodType);
    const note = this._normNote(dto.note);

    try {
      await this.prisma.payment.create({
        data: {
          bookingId: booking.id,
          amountRub,
          method: methodLabel,
          methodType,
          kind,
          paidAt: new Date(),
        },
      });
    } catch (e: any) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException(
          `Payment kind ${kind} already exists for this booking`,
        );
      }
      throw e;
    }

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.PAYMENT_MARKED,
        locationId: shift.locationId,
        userId: user.id,
        shiftId: shift.id,
        bookingId: booking.id,
        clientId: booking.clientId ?? undefined,
        reason: note ?? 'PAYMENT_MARKED',
        payload: { kind, amountRub, methodType, method: methodLabel },
      },
    });

    this.ws.emitBookingChanged(booking.locationId, booking.bayId ?? 1);

    const refreshed = await this.prisma.booking.findUnique({
      where: { id: booking.id },
      include: {
        service: { select: { priceRub: true } },
        payments: { orderBy: { paidAt: 'asc' } },
      },
    });

    const paidTotal = (refreshed?.payments ?? []).reduce(
      (s, p) => s + (p.amountRub ?? 0),
      0,
    );
    const price = refreshed?.service?.priceRub ?? 0;
    const discount = refreshed?.discountRub ?? 0;
    const effectivePrice = Math.max(price - discount, 0);

    return {
      bookingId: booking.id,
      paidTotalRub: paidTotal,
      discountRub: discount,
      effectivePriceRub: effectivePrice,
      remainingRub: Math.max(effectivePrice - paidTotal, 0),
      payments: refreshed?.payments ?? [],
    };
  }

  /* ===================== ADMIN DISCOUNT ===================== */

  async applyDiscount(
    userId: string,
    shiftId: string,
    bookingId: string,
    dto: AdminBookingDiscountDto,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    await this._requireFeature(shift.locationId, 'DISCOUNTS');

    const discountRub = Math.trunc(Number(dto.discountRub));
    if (!Number.isFinite(discountRub) || discountRub < 0) {
      throw new BadRequestException('discountRub must be >= 0');
    }

    const reason = this._normNote((dto as any).reason, 200);
    if (!reason) throw new BadRequestException('reason is required');

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { service: { select: { priceRub: true } } },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.locationId !== shift.locationId) {
      throw new ForbiddenException('Not your location booking');
    }
    if (booking.status === BookingStatus.CANCELED) {
      throw new ConflictException('Booking is canceled');
    }

    const price = booking.service?.priceRub ?? 0;
    if (discountRub > price) {
      throw new BadRequestException('discountRub cannot exceed service price');
    }

    const oldDiscount = booking.discountRub ?? 0;

    const updated = await this.prisma.booking.update({
      where: { id: booking.id },
      data: { discountRub, discountNote: reason },
      select: {
        id: true,
        locationId: true,
        bayId: true,
        discountRub: true,
        discountNote: true,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.BOOKING_DISCOUNT,
        locationId: shift.locationId,
        userId: user.id,
        shiftId: shift.id,
        bookingId: booking.id,
        clientId: booking.clientId ?? undefined,
        reason,
        payload: { oldDiscountRub: oldDiscount, newDiscountRub: discountRub },
      },
    });

    this.ws.emitBookingChanged(updated.locationId, updated.bayId ?? 1);
    return updated;
  }

  /* ===================== BAYS ===================== */

  async listBays(userId: string, shiftId: string) {
    const { shift } = await this._requireActiveShift(userId, shiftId);

    return this.prisma.bay.findMany({
      where: { locationId: shift.locationId },
      orderBy: { number: 'asc' },
      select: {
        id: true,
        number: true,
        isActive: true,
        closedReason: true,
        closedAt: true,
        reopenedAt: true,
      },
    });
  }

  async setBayActive(
    userId: string,
    shiftId: string,
    bayNumber: number,
    isActive: boolean,
    reason?: string,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    const n = Math.trunc(Number(bayNumber));
    if (!Number.isFinite(n) || n < 1 || n > 20) {
      throw new BadRequestException('bayNumber must be 1..20');
    }

    if (!isActive) {
      const r = (reason ?? '').trim();
      if (!r) throw new BadRequestException('reason is required when closing bay');
    }

    const bay = await this.prisma.bay.findUnique({
      where: { locationId_number: { locationId: shift.locationId, number: n } },
      select: { id: true, number: true, isActive: true },
    });
    if (!bay) throw new NotFoundException('Bay not found');

    const now = new Date();

    const updated = await this.prisma.bay.update({
      where: { id: bay.id },
      data: isActive
        ? { isActive: true, reopenedAt: now, closedReason: null, closedAt: null }
        : {
            isActive: false,
            closedAt: now,
            closedReason: (reason ?? '').trim(),
            reopenedAt: null,
          },
      select: {
        id: true,
        number: true,
        isActive: true,
        closedReason: true,
        closedAt: true,
        reopenedAt: true,
        locationId: true,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: isActive ? AuditType.BAY_OPEN : AuditType.BAY_CLOSE,
        locationId: shift.locationId,
        userId: user.id,
        shiftId: shift.id,
        reason: isActive ? 'BAY_OPEN' : (reason ?? '').trim(),
        payload: { bayNumber: n, isActive },
      },
    });

    this.ws.emitBookingChanged(shift.locationId, n);
    return updated;
  }

  // wrappers for controller
  async closeBay(
    userId: string,
    shiftId: string,
    bayNumber: number,
    dto: AdminBayCloseDto,
  ) {
    const reason = (dto as any)?.reason ?? (dto as any)?.closedReason ?? '';
    return this.setBayActive(
      userId,
      shiftId,
      bayNumber,
      false,
      String(reason ?? '').trim(),
    );
  }

  async openBay(
    userId: string,
    shiftId: string,
    bayNumber: number,
    _dto: AdminBayOpenDto,
  ) {
    return this.setBayActive(userId, shiftId, bayNumber, true);
  }

  /* ===================== WAITLIST ===================== */

  async waitlistDay(userId: string, shiftId: string, dateYmd: string) {
    const { shift } = await this._requireActiveShift(userId, shiftId);
    const { from, to } = this._parseDayRangeUTC(dateYmd);

    return this.prisma.waitlistRequest.findMany({
      where: { locationId: shift.locationId, createdAt: { gte: from, lt: to } },
      orderBy: { createdAt: 'asc' },
      include: {
        client: { select: { id: true, phone: true, name: true } },
        car: true,
        service: {
          select: { id: true, name: true, durationMin: true, priceRub: true },
        },
      },
    });
  }

  async getWaitlistDay(userId: string, shiftId: string, dateYmd: string) {
    return this.waitlistDay(userId, shiftId, dateYmd);
  }
}