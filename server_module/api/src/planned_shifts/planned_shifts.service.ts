// C:\dev\carwash\server_module\api\src\planned_shifts\planned_shifts.service.ts
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PlannedShiftStatus, UserRole } from '@prisma/client';
import { CreatePlannedShiftDto } from './dto/create_planned_shift.dto';
import { UpdatePlannedShiftDto } from './dto/update_planned_shift.dto';
import { AssignPlannedWasherDto } from './dto/assign_planned_washer.dto';

@Injectable()
export class PlannedShiftsService {
  constructor(private prisma: PrismaService) {}

  private async _requireAdmin(userId: string) {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, isActive: true, locationId: true },
    });
    if (!u) throw new NotFoundException('User not found');
    if (!u.isActive) throw new ForbiddenException('User is inactive');
    if (u.role !== UserRole.ADMIN) throw new ForbiddenException('Not an admin');
    return u;
  }

  private _parseIso(raw: string, field: string): Date {
    const d = new Date(raw);
    if (isNaN(d.getTime())) throw new BadRequestException(`${field} must be ISO`);
    return d;
  }

  async list(userId: string, fromIso: string, toIso: string) {
    const admin = await this._requireAdmin(userId);

    const from = this._parseIso(fromIso, 'from');
    const to = this._parseIso(toIso, 'to');
    if (to.getTime() <= from.getTime()) throw new BadRequestException('to must be greater than from');

    const rows = await this.prisma.plannedShift.findMany({
      where: {
        locationId: admin.locationId,
        startAt: { gte: from, lt: to },
      },
      orderBy: { startAt: 'asc' },
      include: {
        washers: {
          orderBy: { createdAt: 'asc' },
          include: {
            washer: { select: { id: true, phone: true, name: true, isActive: true } },
          },
        },
      },
    });

    return rows.map((x) => ({
      id: x.id,
      locationId: x.locationId,
      startAt: x.startAt,
      endAt: x.endAt,
      status: x.status,
      note: x.note,
      washers: x.washers.map((w) => ({
        id: w.id,
        washerId: w.washerId,
        plannedBayId: w.plannedBayId,
        note: w.note,
        washer: w.washer,
      })),
    }));
  }

  async create(userId: string, dto: CreatePlannedShiftDto) {
    const admin = await this._requireAdmin(userId);

    const startAt = this._parseIso((dto.startAt ?? '').trim(), 'startAt');
    const endAt = this._parseIso((dto.endAt ?? '').trim(), 'endAt');
    if (endAt.getTime() <= startAt.getTime()) {
      throw new BadRequestException('endAt must be greater than startAt');
    }

    const note = (dto.note ?? '').toString().trim();
    const created = await this.prisma.plannedShift.create({
      data: {
        locationId: admin.locationId,
        createdByUserId: admin.id,
        startAt,
        endAt,
        status: PlannedShiftStatus.DRAFT,
        note: note.length ? note.slice(0, 500) : null,
      },
    });

    return created;
  }

  async update(userId: string, plannedShiftId: string, dto: UpdatePlannedShiftDto) {
    const admin = await this._requireAdmin(userId);

    const ps = await this.prisma.plannedShift.findUnique({
      where: { id: plannedShiftId },
      select: { id: true, locationId: true, status: true, startAt: true, endAt: true },
    });
    if (!ps) throw new NotFoundException('Planned shift not found');
    if (ps.locationId !== admin.locationId) throw new ForbiddenException('Not your location');

    const data: any = {};

    if (dto.startAt != null) data.startAt = this._parseIso(dto.startAt, 'startAt');
    if (dto.endAt != null) data.endAt = this._parseIso(dto.endAt, 'endAt');
    if (dto.note != null) {
      const note = dto.note.toString().trim();
      data.note = note.length ? note.slice(0, 500) : null;
    }
    if (dto.status != null) {
      const s = dto.status.toString().trim().toUpperCase();
      if (!['DRAFT', 'PUBLISHED', 'CANCELED'].includes(s)) {
        throw new BadRequestException('Invalid status');
      }
      data.status = s as PlannedShiftStatus;
    }

    const nextStart = data.startAt ?? ps.startAt;
    const nextEnd = data.endAt ?? ps.endAt;
    if (nextEnd.getTime() <= nextStart.getTime()) {
      throw new BadRequestException('endAt must be greater than startAt');
    }

    return this.prisma.plannedShift.update({
      where: { id: ps.id },
      data,
    });
  }

  async publish(userId: string, plannedShiftId: string) {
    const admin = await this._requireAdmin(userId);

    const ps = await this.prisma.plannedShift.findUnique({
      where: { id: plannedShiftId },
      select: { id: true, locationId: true, status: true },
    });
    if (!ps) throw new NotFoundException('Planned shift not found');
    if (ps.locationId !== admin.locationId) throw new ForbiddenException('Not your location');

    return this.prisma.plannedShift.update({
      where: { id: ps.id },
      data: { status: PlannedShiftStatus.PUBLISHED },
    });
  }

  async assignWasher(userId: string, plannedShiftId: string, dto: AssignPlannedWasherDto) {
    const admin = await this._requireAdmin(userId);

    const ps = await this.prisma.plannedShift.findUnique({
      where: { id: plannedShiftId },
      select: { id: true, locationId: true, status: true },
    });
    if (!ps) throw new NotFoundException('Planned shift not found');
    if (ps.locationId !== admin.locationId) throw new ForbiddenException('Not your location');

    const washerPhone = (dto.washerPhone ?? '').toString().trim();
    if (!washerPhone) throw new BadRequestException('washerPhone is required');

    const washer = await this.prisma.user.findUnique({
      where: { phone: washerPhone },
      select: { id: true, role: true, isActive: true, locationId: true, phone: true, name: true },
    });
    if (!washer) throw new NotFoundException('Washer not found');
    if (!washer.isActive) throw new ForbiddenException('Washer is inactive');
    if (washer.role !== UserRole.WASHER) throw new ForbiddenException('User is not a washer');
    if (washer.locationId !== admin.locationId) throw new ForbiddenException('Washer belongs to another location');

    const plannedBayId = dto.plannedBayId == null ? null : Math.trunc(Number(dto.plannedBayId));
    if (plannedBayId != null && (!Number.isFinite(plannedBayId) || plannedBayId < 1 || plannedBayId > 20)) {
      throw new BadRequestException('plannedBayId must be 1..20');
    }

    const note = (dto.note ?? '').toString().trim();

    try {
      return await this.prisma.plannedShiftWasher.create({
        data: {
          plannedShiftId: ps.id,
          washerId: washer.id,
          plannedBayId,
          note: note.length ? note.slice(0, 300) : null,
        },
        include: { washer: { select: { id: true, phone: true, name: true } } },
      });
    } catch (e) {
      throw new ConflictException('Washer already assigned to this planned shift');
    }
  }

  async removeWasher(userId: string, plannedShiftId: string, washerId: string) {
    const admin = await this._requireAdmin(userId);

    const ps = await this.prisma.plannedShift.findUnique({
      where: { id: plannedShiftId },
      select: { id: true, locationId: true },
    });
    if (!ps) throw new NotFoundException('Planned shift not found');
    if (ps.locationId !== admin.locationId) throw new ForbiddenException('Not your location');

    const row = await this.prisma.plannedShiftWasher.findFirst({
      where: { plannedShiftId: ps.id, washerId },
      select: { id: true },
    });
    if (!row) throw new NotFoundException('Washer is not assigned to this planned shift');

    await this.prisma.plannedShiftWasher.delete({ where: { id: row.id } });
    return { ok: true };
  }
}
