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
  ShiftStatus,
  UserRole,
  Prisma,
} from '@prisma/client';
import { BookingsGateway } from '../bookings/bookings.gateway';
import { AdminLoginDto } from './dto/admin-login.dto';
import { AdminBookingStartDto } from './dto/admin-booking-start.dto';
import { AdminBookingFinishDto } from './dto/admin-booking-finish.dto';
import { AdminBookingMoveDto } from './dto/admin-booking-move.dto';

@Injectable()
export class AdminService {
  // Сетка слотов должна совпадать с BookingsService
  private static readonly SLOT_STEP_MIN = 30;

  constructor(
    private prisma: PrismaService,
    private ws: BookingsGateway,
  ) {}

  private _requireAdmin(user: { role: UserRole; isActive: boolean }) {
    if (!user.isActive) throw new ForbiddenException('User is inactive');
    if (user.role !== UserRole.ADMIN) throw new ForbiddenException('Not an admin');
  }

  private _parseIsoOrNow(raw?: string): Date {
    if (!raw) return new Date();
    const d = new Date(raw);
    if (isNaN(d.getTime())) throw new BadRequestException('Invalid ISO date');
    return d;
  }

  private _parseDayRangeUTC(dateYmd: string): { from: Date; to: Date } {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateYmd)) {
      throw new BadRequestException('date must be YYYY-MM-DD');
    }
    const from = new Date(`${dateYmd}T00:00:00.000Z`);
    const to = new Date(from.getTime() + 24 * 60 * 60 * 1000);
    return { from, to };
  }

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
      select: { id: true, openedAt: true, locationId: true, adminId: true, status: true },
    });

    await this.prisma.auditEvent.create({
      data: {
        type: AuditType.SHIFT_OPEN,
        locationId: user.locationId,
        userId: user.id,
        shiftId: shift.id,
        reason: 'SHIFT_OPEN',
        payload: { openedAt: shift.openedAt.toISOString() },
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
        payload: { closedAt: now.toISOString() },
      },
    });

    await this.prisma.user.update({
      where: { id: user.id },
      data: { shiftCloseAt: now },
    });

    return updated;
  }

  async getCalendarDay(userId: string, shiftId: string, dateYmd: string) {
    const { shift } = await this._requireActiveShift(userId, shiftId);
    const { from, to } = this._parseDayRangeUTC(dateYmd);

    return this.prisma.booking.findMany({
      where: {
        locationId: shift.locationId,
        dateTime: { gte: from, lt: to },
      },
      orderBy: [{ bayId: 'asc' }, { dateTime: 'asc' }],
      select: {
        id: true,
        dateTime: true,
        bayId: true,
        bufferMin: true,
        comment: true,
        adminNote: true,
        startedAt: true,
        finishedAt: true,
        status: true,
        canceledAt: true,
        cancelReason: true,
        clientId: true,
        car: {
          select: {
            id: true,
            plateDisplay: true,
            makeDisplay: true,
            modelDisplay: true,
            color: true,
            bodyType: true,
          },
        },
        client: {
          select: { id: true, phone: true, name: true },
        },
        service: {
          select: { id: true, name: true, durationMin: true },
        },
      },
    });
  }

  async startBooking(
    userId: string,
    shiftId: string,
    bookingId: string,
    dto?: AdminBookingStartDto,
  ) {
    const { user, shift } = await this._requireActiveShift(userId, shiftId);

    const startedAt = this._parseIsoOrNow(dto?.startedAt);
    const note =
      typeof dto?.adminNote === 'string' && dto.adminNote.trim().length > 0
        ? dto.adminNote.trim().slice(0, 500)
        : null;

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
        payload: { startedAt: updated.startedAt?.toISOString() ?? null },
      },
    });

    // ✅ WS notify
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
    const { tx, bookingId, locationId, bayId, carId, newStart, durationTotalMin } = args;

    const newEnd = this._end(newStart, durationTotalMin);
    const windowStart = new Date(newStart.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(newEnd.getTime() + 24 * 60 * 60 * 1000);

    const busyStatuses: BookingStatus[] = [
      BookingStatus.ACTIVE,
      BookingStatus.PENDING_PAYMENT,
    ];

    const now = new Date();

    // 1) по посту в рамках локации
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
      const total = this._roundUpToStepMin(raw, AdminService.SLOT_STEP_MIN);
      const bStart = b.dateTime;
      const bEnd = this._end(bStart, total);
      return this._overlaps(newStart, newEnd, bStart, bEnd);
    });

    if (anyOverlap) {
      throw new ConflictException('Selected time slot is already booked');
    }

    // 2) по машине глобально (чтобы не было двух броней одновременно)
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
      const total = this._roundUpToStepMin(raw, AdminService.SLOT_STEP_MIN);
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

    const newDateTimeRaw = (dto?.newDateTime ?? '').trim();
    if (!newDateTimeRaw) throw new BadRequestException('newDateTime is required');
    const newDateTime = new Date(newDateTimeRaw);
    if (isNaN(newDateTime.getTime())) {
      throw new BadRequestException('newDateTime must be ISO');
    }

    const reason = (dto?.reason ?? '').trim();
    if (!reason) throw new BadRequestException('reason is required');

    const clientAgreed = dto?.clientAgreed === true;
    if (!clientAgreed) {
      throw new BadRequestException('clientAgreed must be true');
    }

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
        shiftId: true,
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

    // duration for conflict-check
    const baseDur = this._serviceDurationOrDefault(existing.service?.durationMin);
    const rawDur = baseDur + (existing.bufferMin ?? 0);
    const durTotal = this._roundUpToStepMin(rawDur, AdminService.SLOT_STEP_MIN);

    const updated = await this.prisma.$transaction(async (tx) => {
      // ✅ check conflicts
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
        data: {
          shiftId: shift.id,
          dateTime: newDateTime,
          bayId: nextBayId,
        },
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
            clientAgreed,
            oldValue,
            newValue: { dateTime: u.dateTime.toISOString(), bayId: u.bayId },
          },
        },
      });

      return u;
    });

    // ✅ WS notify (если сменили пост — шлём на старый и новый)
    const oldBay = oldValue.bayId;
    const newBay = updated.bayId;

    this.ws.emitBookingChanged(updated.locationId, oldBay);
    if (newBay !== oldBay) {
      this.ws.emitBookingChanged(updated.locationId, newBay);
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
    const note =
      typeof dto?.adminNote === 'string' && dto.adminNote.trim().length > 0
        ? dto.adminNote.trim().slice(0, 500)
        : null;

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
        payload: { finishedAt: updated.finishedAt?.toISOString() ?? null },
      },
    });

    // ✅ WS notify
    this.ws.emitBookingChanged(updated.locationId, updated.bayId ?? 1);

    return updated;
  }
}
