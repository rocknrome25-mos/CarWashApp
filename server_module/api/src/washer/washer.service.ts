// C:\dev\carwash\server_module\api\src\washer\washer.service.ts
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  BookingStatus,
  ServiceLaborCategory,
  ShiftStatus,
  UserRole,
  WasherClockEventType,
} from '@prisma/client';
import { WasherLoginDto } from './dto/washer-login.dto';
import { WasherClockDto } from './dto/washer-clock.dto';

@Injectable()
export class WasherService {
  constructor(private prisma: PrismaService) {}

  /* ===================== helpers ===================== */

  private _parseIsoOrNow(raw?: string): Date {
    if (!raw) return new Date();
    const d = new Date(raw);
    if (isNaN(d.getTime())) throw new BadRequestException('Invalid ISO date');
    return d;
  }

  private _requireWasher(user: { role: UserRole; isActive: boolean }) {
    if (!user.isActive) throw new ForbiddenException('User is inactive');
    if (user.role !== UserRole.WASHER) throw new ForbiddenException('Not a washer');
  }

  private async _getWasherOrThrow(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, isActive: true, locationId: true, phone: true, name: true },
    });
    if (!user) throw new NotFoundException('User not found');
    this._requireWasher(user);
    return user;
  }

  private async _getCurrentAssignmentOrThrow(washerId: string) {
    // latest assignment where shift is OPEN
    const row = await this.prisma.shiftWasher.findFirst({
      where: {
        washerId,
        shift: { status: ShiftStatus.OPEN },
      },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        bayId: true,
        clockInAt: true,
        clockOutAt: true,
        percentWash: true,
        percentChem: true,
        shift: {
          select: {
            id: true,
            status: true,
            openedAt: true,
            closedAt: true,
            locationId: true,
            admin: { select: { id: true, phone: true, name: true } },
          },
        },
      },
    });

    if (!row) {
      throw new NotFoundException('No active shift assignment for this washer');
    }
    return row;
  }

  private _safePercent(p: unknown, def: number) {
    const n = typeof p === 'number' ? p : Number(p);
    if (!Number.isFinite(n)) return def;
    const x = Math.trunc(n);
    if (x < 0) return 0;
    if (x > 100) return 100;
    return x;
  }

  /* ===================== auth ===================== */

  async login(dto: WasherLoginDto) {
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
    this._requireWasher(user);

    // show if they already have an OPEN shift assignment
    const activeAssign = await this.prisma.shiftWasher.findFirst({
      where: {
        washerId: user.id,
        shift: { status: ShiftStatus.OPEN },
      },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        bayId: true,
        clockInAt: true,
        clockOutAt: true,
        shift: { select: { id: true, openedAt: true, locationId: true } },
      },
    });

    return {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        locationId: user.locationId,
      },
      activeShiftId: activeAssign?.shift?.id ?? null,
      activeShiftOpenedAt: activeAssign?.shift?.openedAt ?? null,
      activeBayId: activeAssign?.bayId ?? null,
      clockInAt: activeAssign?.clockInAt ?? null,
      clockOutAt: activeAssign?.clockOutAt ?? null,
    };
  }

  /* ===================== current shift ===================== */

  async getCurrentShift(washerId: string) {
    const washer = await this._getWasherOrThrow(washerId);
    const asg = await this._getCurrentAssignmentOrThrow(washer.id);

    // counts for this shift+bay
    const completedCount = await this.prisma.booking.count({
      where: {
        shiftId: asg.shift.id,
        bayId: asg.bayId,
        status: BookingStatus.COMPLETED,
      },
    });

    // earnings for this shift+bay (computed server-side, not exposing prices)
    const earningsRub = await this._computeEarningsForShiftBay({
      shiftId: asg.shift.id,
      bayId: asg.bayId,
      percentWash: asg.percentWash,
      percentChem: asg.percentChem,
    });

    return {
      washer: { id: washer.id, phone: washer.phone, name: washer.name, locationId: washer.locationId },
      shift: {
        id: asg.shift.id,
        status: asg.shift.status,
        openedAt: asg.shift.openedAt,
        closedAt: asg.shift.closedAt,
        locationId: asg.shift.locationId,
      },
      bayId: asg.bayId,
      adminOnDuty: asg.shift.admin,
      clock: {
        clockInAt: asg.clockInAt,
        clockOutAt: asg.clockOutAt,
        canClockIn: !asg.clockInAt,
        canClockOut: !!asg.clockInAt && !asg.clockOutAt,
      },
      totals: {
        carsCompleted: completedCount,
        earningsRub,
      },
    };
  }

  async getCurrentShiftBookings(washerId: string) {
    const washer = await this._getWasherOrThrow(washerId);
    const asg = await this._getCurrentAssignmentOrThrow(washer.id);

    const rows = await this.prisma.booking.findMany({
      where: {
        shiftId: asg.shift.id,
        bayId: asg.bayId,
        // показываем всё, что относится к смене (в т.ч. completed) — UI сам отфильтрует
        status: { in: [BookingStatus.PENDING_PAYMENT, BookingStatus.ACTIVE, BookingStatus.COMPLETED, BookingStatus.CANCELED] },
      },
      orderBy: { dateTime: 'asc' },
      select: {
        id: true,
        dateTime: true,
        bayId: true,
        status: true,
        comment: true,
        adminNote: true,
        startedAt: true,
        finishedAt: true,
        canceledAt: true,
        cancelReason: true,

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

        // ✅ NO prices for washer app
        service: {
          select: {
            id: true,
            name: true,
            durationMin: true,
            kind: true,
            laborCategory: true,
          },
        },

        addons: {
          orderBy: { createdAt: 'asc' },
          select: {
            serviceId: true,
            qty: true,
            note: true,
            service: { select: { id: true, name: true, kind: true, laborCategory: true } }, // no price
          },
        },
      },
    });

    return {
      shiftId: asg.shift.id,
      bayId: asg.bayId,
      bookings: rows.map((b) => ({
        id: b.id,
        dateTime: b.dateTime,
        bayId: b.bayId,
        status: b.status,
        startedAt: b.startedAt,
        finishedAt: b.finishedAt,
        canceledAt: b.canceledAt,
        cancelReason: b.cancelReason,

        // ✅ instructions
        comment: b.comment,
        adminNote: b.adminNote,

        car: b.car,
        service: b.service,
        addons: (b.addons ?? []).map((a) => ({
          serviceId: a.serviceId,
          qty: a.qty,
          note: a.note,
          service: a.service ? { id: a.service.id, name: a.service.name } : null,
        })),
      })),
    };
  }

  /* ===================== clock-in/out ===================== */

  async clockIn(washerId: string, dto: WasherClockDto) {
    const washer = await this._getWasherOrThrow(washerId);
    const asg = await this._getCurrentAssignmentOrThrow(washer.id);

    if (asg.clockInAt) {
      return {
        ok: true,
        shiftWasherId: asg.id,
        clockInAt: asg.clockInAt,
        clockOutAt: asg.clockOutAt,
        message: 'Already clocked-in',
      };
    }

    const at = this._parseIsoOrNow(dto?.at);

    const updated = await this.prisma.$transaction(async (tx) => {
      const u = await tx.shiftWasher.update({
        where: { id: asg.id },
        data: { clockInAt: at },
        select: { id: true, clockInAt: true, clockOutAt: true },
      });

      await tx.washerClockEvent.create({
        data: {
          shiftWasherId: asg.id,
          type: WasherClockEventType.CLOCK_IN,
          at,
        },
        select: { id: true },
      });

      return u;
    });

    return {
      ok: true,
      shiftWasherId: updated.id,
      clockInAt: updated.clockInAt,
      clockOutAt: updated.clockOutAt,
    };
  }

  async clockOut(washerId: string, dto: WasherClockDto) {
    const washer = await this._getWasherOrThrow(washerId);
    const asg = await this._getCurrentAssignmentOrThrow(washer.id);

    if (!asg.clockInAt) {
      throw new ConflictException('Cannot clock-out before clock-in');
    }
    if (asg.clockOutAt) {
      return {
        ok: true,
        shiftWasherId: asg.id,
        clockInAt: asg.clockInAt,
        clockOutAt: asg.clockOutAt,
        message: 'Already clocked-out',
      };
    }

    const at = this._parseIsoOrNow(dto?.at);

    const updated = await this.prisma.$transaction(async (tx) => {
      const u = await tx.shiftWasher.update({
        where: { id: asg.id },
        data: { clockOutAt: at },
        select: { id: true, clockInAt: true, clockOutAt: true },
      });

      await tx.washerClockEvent.create({
        data: {
          shiftWasherId: asg.id,
          type: WasherClockEventType.CLOCK_OUT,
          at,
        },
        select: { id: true },
      });

      return u;
    });

    return {
      ok: true,
      shiftWasherId: updated.id,
      clockInAt: updated.clockInAt,
      clockOutAt: updated.clockOutAt,
    };
  }

  /* ===================== stats ===================== */

  async getStats(washerId: string, fromIso: string, toIso: string) {
    const washer = await this._getWasherOrThrow(washerId);

    const from = new Date(fromIso);
    const to = new Date(toIso);
    if (isNaN(from.getTime()) || isNaN(to.getTime())) {
      throw new BadRequestException('from/to must be ISO');
    }
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('to must be greater than from');
    }

    // find assignments overlapping this period (based on shift.openedAt)
    const assignments = await this.prisma.shiftWasher.findMany({
      where: {
        washerId: washer.id,
        shift: {
          openedAt: { gte: from, lt: to },
        },
      },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        bayId: true,
        percentWash: true,
        percentChem: true,
        shift: {
          select: {
            id: true,
            openedAt: true,
            closedAt: true,
            status: true,
            locationId: true,
          },
        },
      },
    });

    if (assignments.length === 0) {
      return {
        washer: { id: washer.id, phone: washer.phone, name: washer.name },
        from,
        to,
        totals: { carsCompleted: 0, earningsRub: 0 },
        breakdown: [],
      };
    }

    const breakdown: Array<{
      shiftId: string;
      openedAt: Date;
      bayId: number;
      carsCompleted: number;
      earningsRub: number;
    }> = [];

    let totalCars = 0;
    let totalEarnings = 0;

    for (const a of assignments) {
      const carsCompleted = await this.prisma.booking.count({
        where: {
          shiftId: a.shift.id,
          bayId: a.bayId,
          status: BookingStatus.COMPLETED,
        },
      });

      const earningsRub = await this._computeEarningsForShiftBay({
        shiftId: a.shift.id,
        bayId: a.bayId,
        percentWash: a.percentWash,
        percentChem: a.percentChem,
      });

      totalCars += carsCompleted;
      totalEarnings += earningsRub;

      breakdown.push({
        shiftId: a.shift.id,
        openedAt: a.shift.openedAt,
        bayId: a.bayId,
        carsCompleted,
        earningsRub,
      });
    }

    return {
      washer: { id: washer.id, phone: washer.phone, name: washer.name },
      from,
      to,
      totals: { carsCompleted: totalCars, earningsRub: totalEarnings },
      breakdown,
    };
  }

  /* ===================== earnings computation (internal) ===================== */

  private async _computeEarningsForShiftBay(args: {
    shiftId: string;
    bayId: number;
    percentWash: number;
    percentChem: number;
  }): Promise<number> {
    const pWash = this._safePercent(args.percentWash, 30);
    const pChem = this._safePercent(args.percentChem, 40);

    // We need prices internally, but we do NOT return them.
    const bookings = await this.prisma.booking.findMany({
      where: {
        shiftId: args.shiftId,
        bayId: args.bayId,
        status: BookingStatus.COMPLETED,
      },
      select: {
        discountRub: true,
        service: { select: { priceRub: true, laborCategory: true } },
      },
    });

    let sum = 0;

    for (const b of bookings) {
      const price = b.service?.priceRub ?? 0;
      const discount = b.discountRub ?? 0;
      const base = Math.max(price - discount, 0);

      const cat = b.service?.laborCategory ?? ServiceLaborCategory.WASH;
      const percent = cat === ServiceLaborCategory.CHEM ? pChem : pWash;

      const earn = Math.trunc((base * percent) / 100);
      sum += earn;
    }

    return sum;
  }
}
