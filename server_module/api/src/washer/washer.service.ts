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
  PlannedShiftStatus,
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

  private _parseIso(raw: string, field: string): Date {
    const d = new Date(raw);
    if (isNaN(d.getTime())) throw new BadRequestException(`${field} must be ISO`);
    return d;
  }

  private _startOfDay(d: Date): Date {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
  }

  private _endOfDay(d: Date): Date {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
  }

  private _requireWasher(user: { role: UserRole; isActive: boolean }) {
    if (!user.isActive) throw new ForbiddenException('User is inactive');
    if (user.role !== UserRole.WASHER) throw new ForbiddenException('Not a washer');
  }

  private async _getWasherOrThrow(userId: string) {
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
    this._requireWasher(user);
    return user;
  }

  private async _getCurrentAssignmentOrNull(washerId: string) {
    return this.prisma.shiftWasher.findFirst({
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
            plannedShiftId: true,
            admin: { select: { id: true, phone: true, name: true } },
            location: {
              select: {
                id: true,
                name: true,
                address: true,
                colorHex: true,
                baysCount: true,
              },
            },
            plannedShift: {
              select: {
                id: true,
                startAt: true,
                endAt: true,
                note: true,
                status: true,
              },
            },
          },
        },
      },
    });
  }

  private async _getCurrentAssignmentOrThrow(washerId: string) {
    const row = await this._getCurrentAssignmentOrNull(washerId);
    if (!row) {
      throw new NotFoundException('No active shift assignment for this washer');
    }
    return row;
  }

  private async _getTodayPlannedAssignmentOrNull(
    washerId: string,
    at = new Date(),
  ) {
    const from = this._startOfDay(at);
    const to = this._endOfDay(at);

    return this.prisma.plannedShiftWasher.findFirst({
      where: {
        washerId,
        plannedShift: {
          startAt: { gte: from, lte: to },
          status: PlannedShiftStatus.PUBLISHED,
        },
      },
      orderBy: { plannedShift: { startAt: 'asc' } },
      select: {
        id: true,
        plannedBayId: true,
        note: true,
        plannedShift: {
          select: {
            id: true,
            locationId: true,
            createdByUserId: true,
            startAt: true,
            endAt: true,
            status: true,
            note: true,
            createdByUser: {
              select: { id: true, phone: true, name: true },
            },
            location: {
              select: {
                id: true,
                name: true,
                address: true,
                colorHex: true,
                baysCount: true,
              },
            },
          },
        },
      },
    });
  }

  private async _getPayPercents(locationId: string) {
    const rules = await this.prisma.washerPayRule.findMany({
      where: {
        locationId,
        isActive: true,
      },
      select: {
        category: true,
        percent: true,
      },
    });

    let percentWash = 30;
    let percentChem = 40;

    for (const r of rules) {
      if (r.category === ServiceLaborCategory.WASH) {
        percentWash = this._safePercent(r.percent, 30);
      } else if (r.category === ServiceLaborCategory.CHEM) {
        percentChem = this._safePercent(r.percent, 40);
      }
    }

    return { percentWash, percentChem };
  }

  private async _ensureLiveAssignmentForTodayPlannedShift(args: {
    washerId: string;
    at: Date;
  }) {
    const { washerId, at } = args;

    const existing = await this._getCurrentAssignmentOrNull(washerId);
    if (existing) return existing;

    const planned = await this._getTodayPlannedAssignmentOrNull(washerId, at);
    if (!planned) {
      throw new NotFoundException('No planned shift assignment for today');
    }

    if (planned.plannedBayId == null) {
      throw new ConflictException('Planned shift has no assigned bay');
    }

    const bayId = planned.plannedBayId;

    if (at.getTime() < planned.plannedShift.startAt.getTime()) {
      throw new ConflictException('Shift has not started yet');
    }

    if (at.getTime() > planned.plannedShift.endAt.getTime()) {
      throw new ConflictException('Planned shift already ended');
    }

    const pay = await this._getPayPercents(planned.plannedShift.locationId);

    await this.prisma.$transaction(async (tx) => {
      let liveShift = await tx.shift.findFirst({
        where: {
          plannedShiftId: planned.plannedShift.id,
          status: ShiftStatus.OPEN,
        },
        select: { id: true },
      });

      if (!liveShift) {
        liveShift = await tx.shift.create({
          data: {
            locationId: planned.plannedShift.locationId,
            adminId: planned.plannedShift.createdByUserId,
            status: ShiftStatus.OPEN,
            openedAt: at,
            plannedShiftId: planned.plannedShift.id,
          },
          select: { id: true },
        });
      }

      const existingAsg = await tx.shiftWasher.findFirst({
        where: {
          shiftId: liveShift.id,
          washerId,
        },
        select: { id: true },
      });

      if (!existingAsg) {
        await tx.shiftWasher.create({
          data: {
            shiftId: liveShift.id,
            washerId,
            bayId,
            percentWash: pay.percentWash,
            percentChem: pay.percentChem,
          },
          select: { id: true },
        });
      }
    });

    const created = await this._getCurrentAssignmentOrNull(washerId);
    if (!created) {
      throw new ConflictException('Failed to create live shift assignment');
    }
    return created;
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

    const liveAsg = await this._getCurrentAssignmentOrNull(washer.id);
    if (liveAsg) {
      const completedCount = await this.prisma.booking.count({
        where: {
          shiftId: liveAsg.shift.id,
          bayId: liveAsg.bayId,
          status: BookingStatus.COMPLETED,
        },
      });

      const earningsRub = await this._computeEarningsForShiftBay({
        shiftId: liveAsg.shift.id,
        bayId: liveAsg.bayId,
        percentWash: liveAsg.percentWash,
        percentChem: liveAsg.percentChem,
      });

      return {
        washer: {
          id: washer.id,
          phone: washer.phone,
          name: washer.name,
          locationId: washer.locationId,
        },
        shift: {
          id: liveAsg.shift.id,
          status: liveAsg.shift.status,
          openedAt: liveAsg.shift.openedAt,
          closedAt: liveAsg.shift.closedAt,
          locationId: liveAsg.shift.locationId,
          plannedShiftId: liveAsg.shift.plannedShiftId ?? null,
        },
        startAt:
          liveAsg.shift.plannedShift?.startAt ??
          liveAsg.shift.openedAt ??
          null,
        endAt: liveAsg.shift.plannedShift?.endAt ?? null,
        note: liveAsg.shift.plannedShift?.note ?? null,
        location: liveAsg.shift.location,
        bayId: liveAsg.bayId,
        adminOnDuty: liveAsg.shift.admin,
        clock: {
          clockInAt: liveAsg.clockInAt,
          clockOutAt: liveAsg.clockOutAt,
          canClockIn: !liveAsg.clockInAt,
          canClockOut: !!liveAsg.clockInAt && !liveAsg.clockOutAt,
        },
        totals: {
          carsCompleted: completedCount,
          earningsRub,
        },
      };
    }

    const now = new Date();
    const planned = await this._getTodayPlannedAssignmentOrNull(washer.id, now);
    if (!planned) {
      throw new NotFoundException(
        'No active or planned shift assignment for this washer',
      );
    }

    const canClockIn =
      planned.plannedBayId != null &&
      now.getTime() >= planned.plannedShift.startAt.getTime() &&
      now.getTime() <= planned.plannedShift.endAt.getTime();

    return {
      washer: {
        id: washer.id,
        phone: washer.phone,
        name: washer.name,
        locationId: washer.locationId,
      },
      shift: {
        id: planned.plannedShift.id,
        status: 'PLANNED',
        openedAt: null,
        closedAt: null,
        locationId: planned.plannedShift.locationId,
        plannedShiftId: planned.plannedShift.id,
      },
      startAt: planned.plannedShift.startAt,
      endAt: planned.plannedShift.endAt,
      note: planned.plannedShift.note,
      location: planned.plannedShift.location,
      bayId: planned.plannedBayId,
      adminOnDuty: planned.plannedShift.createdByUser,
      clock: {
        clockInAt: null,
        clockOutAt: null,
        canClockIn,
        canClockOut: false,
      },
      totals: {
        carsCompleted: 0,
        earningsRub: 0,
      },
    };
  }

  async getCurrentShiftBookings(washerId: string) {
    const washer = await this._getWasherOrThrow(washerId);
    const liveAsg = await this._getCurrentAssignmentOrNull(washer.id);

    if (!liveAsg) {
      const planned = await this._getTodayPlannedAssignmentOrNull(
        washer.id,
        new Date(),
      );
      if (!planned) {
        throw new NotFoundException(
          'No active or planned shift assignment for this washer',
        );
      }

      return {
        shiftId: null,
        bayId: planned.plannedBayId,
        bookings: [],
      };
    }

    const rows = await this.prisma.booking.findMany({
      where: {
        shiftId: liveAsg.shift.id,
        bayId: liveAsg.bayId,
        status: {
          in: [
            BookingStatus.PENDING_PAYMENT,
            BookingStatus.ACTIVE,
            BookingStatus.COMPLETED,
            BookingStatus.CANCELED,
          ],
        },
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
            service: {
              select: {
                id: true,
                name: true,
                kind: true,
                laborCategory: true,
              },
            },
          },
        },
      },
    });

    return {
      shiftId: liveAsg.shift.id,
      bayId: liveAsg.bayId,
      bookings: rows.map((b) => ({
        id: b.id,
        dateTime: b.dateTime,
        bayId: b.bayId,
        status: b.status,
        startedAt: b.startedAt,
        finishedAt: b.finishedAt,
        canceledAt: b.canceledAt,
        cancelReason: b.cancelReason,
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
    const at = this._parseIsoOrNow(dto?.at);

    const asg = await this._ensureLiveAssignmentForTodayPlannedShift({
      washerId: washer.id,
      at,
    });

    if (asg.clockInAt) {
      return {
        ok: true,
        shiftWasherId: asg.id,
        clockInAt: asg.clockInAt,
        clockOutAt: asg.clockOutAt,
        message: 'Already clocked-in',
      };
    }

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

    const from = this._parseIso(fromIso, 'from');
    const to = this._parseIso(toIso, 'to');
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('to must be greater than from');
    }

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

  /* ===================== schedule (planned shifts) ===================== */

  async getSchedule(washerId: string, fromIso: string, toIso: string) {
    const washer = await this._getWasherOrThrow(washerId);

    const from = this._parseIso(fromIso, 'from');
    const to = this._parseIso(toIso, 'to');
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('to must be greater than from');
    }

    const rows = await this.prisma.plannedShiftWasher.findMany({
      where: {
        washerId: washer.id,
        plannedShift: {
          startAt: { gte: from, lt: to },
          status: { in: [PlannedShiftStatus.DRAFT, PlannedShiftStatus.PUBLISHED] },
        },
      },
      orderBy: { plannedShift: { startAt: 'asc' } },
      include: {
        plannedShift: {
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
          },
        },
      },
    });

    return {
      washer: {
        id: washer.id,
        phone: washer.phone,
        name: washer.name,
        locationId: washer.locationId,
      },
      from,
      to,
      shifts: rows.map((r) => ({
        id: r.plannedShift.id,
        status: r.plannedShift.status,
        startAt: r.plannedShift.startAt,
        endAt: r.plannedShift.endAt,
        note: r.plannedShift.note,
        plannedBayId: r.plannedBayId,
        location: r.plannedShift.location,
      })),
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