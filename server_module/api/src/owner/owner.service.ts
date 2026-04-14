import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditType, BookingStatus, PaymentMethodType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { promisify } from 'node:util';
import { randomBytes, scrypt as scryptCallback } from 'node:crypto';

type Period = 'day' | 'month' | 'year';

const scryptAsync = promisify(scryptCallback);

@Injectable()
export class OwnerService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly locationName = 'ЖК Рассказово';

  private parsePeriod(raw?: string): Period {
    if (raw === 'day' || raw === 'month' || raw === 'year') {
      return raw;
    }
    return 'month';
  }

  private async getLocation() {
    const location = await this.prisma.location.findUnique({
      where: { name: this.locationName },
    });

    if (!location) {
      throw new NotFoundException(
        `Location "${this.locationName}" not found`,
      );
    }

    return location;
  }

  private getRange(period: Period) {
    const now = new Date();

    if (period === 'day') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const end = new Date(start);
      end.setDate(end.getDate() + 1);
      return { start, end };
    }

    if (period === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
      return { start, end };
    }

    const start = new Date(now.getFullYear(), 0, 1);
    const end = new Date(now.getFullYear() + 1, 0, 1);
    return { start, end };
  }

  private readonly suspiciousAuditTypes: AuditType[] = [
    AuditType.BOOKING_CHANGE_SERVICE,
    AuditType.BOOKING_CHANGE_BODYTYPE,
    AuditType.BOOKING_DISCOUNT,
    AuditType.BOOKING_DELETE,
    AuditType.WAITLIST_DELETE,
    AuditType.BAY_OPEN,
    AuditType.BAY_CLOSE,
  ];

  private normalizePhone(raw: string): string {
    const value = raw.trim();
    if (!value) {
      throw new BadRequestException('Телефон обязателен.');
    }

    const allowed = /^\+?[0-9]{10,15}$/;
    if (!allowed.test(value)) {
      throw new BadRequestException(
        'Телефон должен содержать только цифры и при необходимости знак + в начале.',
      );
    }

    return value;
  }

  private normalizeName(raw: string): string {
    const value = raw.trim();
    if (!value) {
      throw new BadRequestException('Имя обязательно.');
    }
    if (value.length < 2) {
      throw new BadRequestException('Имя слишком короткое.');
    }
    if (value.length > 100) {
      throw new BadRequestException('Имя слишком длинное.');
    }
    return value;
  }

  private parseEmployeeRole(raw?: string): 'ADMIN' | 'WASHER' {
  if (raw === 'ADMIN') return 'ADMIN';
  if (raw === 'WASHER') return 'WASHER';

  throw new BadRequestException(
    'Разрешены только роли ADMIN или WASHER.',
  );
}

  private validatePassword(raw?: string): string {
    const value = (raw ?? '').trim();

    if (!value) {
      throw new BadRequestException('Пароль обязателен.');
    }

    if (value.length < 6) {
      throw new BadRequestException('Пароль должен быть не короче 6 символов.');
    }

    if (value.length > 128) {
      throw new BadRequestException('Пароль слишком длинный.');
    }

    return value;
  }

  private async hashPassword(password: string): Promise<string> {
    const salt = randomBytes(16).toString('hex');
    const derivedKey = (await scryptAsync(password, salt, 64)) as Buffer;
    return `scrypt$${salt}$${derivedKey.toString('hex')}`;
  }

  async getSummary(rawPeriod?: string) {
    const period = this.parsePeriod(rawPeriod);
    const location = await this.getLocation();
    const { start, end } = this.getRange(period);

    const [
      clientsTotal,
      newClients,
      clientsWithContacts,
      servicedBookings,
      suspiciousEvents,
      discountedBookings,
      revenueAgg,
      activeShift,
      paymentMethods,
      blockedClients,
      waitlistWaiting,
      admins,
      washers,
      topServicesRaw,
    ] = await Promise.all([
      this.prisma.clientLocation.count({
        where: { locationId: location.id },
      }),

      this.prisma.clientLocation.count({
        where: {
          locationId: location.id,
          createdAt: { gte: start, lt: end },
        },
      }),

      this.prisma.client.count({
        where: {
          bookings: {
            some: {
              locationId: location.id,
            },
          },
          phone: { not: '' },
        },
      }),

      this.prisma.booking.count({
        where: {
          locationId: location.id,
          status: BookingStatus.COMPLETED,
          dateTime: { gte: start, lt: end },
        },
      }),

      this.prisma.auditEvent.count({
        where: {
          locationId: location.id,
          createdAt: { gte: start, lt: end },
          type: { in: this.suspiciousAuditTypes },
        },
      }),

      this.prisma.booking.count({
        where: {
          locationId: location.id,
          dateTime: { gte: start, lt: end },
          discountRub: { gt: 0 },
        },
      }),

      this.prisma.payment.aggregate({
        where: {
          booking: { locationId: location.id },
          paidAt: { gte: start, lt: end },
        },
        _sum: { amountRub: true },
        _count: { _all: true },
      }),

      this.prisma.shift.findFirst({
        where: {
          locationId: location.id,
          status: 'OPEN',
        },
        orderBy: { openedAt: 'desc' },
        include: {
          admin: {
            select: { id: true, name: true, phone: true },
          },
        },
      }),

      this.prisma.payment.groupBy({
        by: ['methodType'],
        where: {
          booking: { locationId: location.id },
          paidAt: { gte: start, lt: end },
        },
        _sum: { amountRub: true },
        _count: { _all: true },
      }),

      this.prisma.clientLocation.count({
        where: {
          locationId: location.id,
          isBlocked: true,
        },
      }),

      this.prisma.waitlistRequest.count({
        where: {
          locationId: location.id,
          status: 'WAITING',
        },
      }),

      this.prisma.user.count({
        where: {
          locationId: location.id,
          role: 'ADMIN',
          isActive: true,
        },
      }),

      this.prisma.user.count({
        where: {
          locationId: location.id,
          role: 'WASHER',
          isActive: true,
        },
      }),

      this.prisma.booking.groupBy({
        by: ['serviceId'],
        where: {
          locationId: location.id,
          dateTime: { gte: start, lt: end },
        },
        _count: { _all: true },
      }),
    ]);

    const topServiceIds = topServicesRaw
      .sort((a, b) => b._count._all - a._count._all)
      .slice(0, 5)
      .map((x) => x.serviceId);

    const topServicesMeta =
      topServiceIds.length === 0
        ? []
        : await this.prisma.service.findMany({
            where: { id: { in: topServiceIds } },
            select: {
              id: true,
              name: true,
              kind: true,
            },
          });

    const topServices = topServicesRaw
      .sort((a, b) => b._count._all - a._count._all)
      .slice(0, 5)
      .map((row) => {
        const meta = topServicesMeta.find((s) => s.id === row.serviceId);
        return {
          serviceId: row.serviceId,
          name: meta?.name ?? 'Unknown service',
          kind: meta?.kind ?? 'BASE',
          bookingsCount: row._count._all,
        };
      });

    const revenue = revenueAgg._sum.amountRub ?? 0;
    const averageCheck =
      revenueAgg._count._all > 0
        ? Math.round(revenue / revenueAgg._count._all)
        : 0;

    const paymentSplit = {
      cash: 0,
      card: 0,
      contract: 0,
    };

    for (const row of paymentMethods) {
      const sum = row._sum.amountRub ?? 0;
      if (row.methodType === PaymentMethodType.CASH) paymentSplit.cash = sum;
      if (row.methodType === PaymentMethodType.CARD) paymentSplit.card = sum;
      if (row.methodType === PaymentMethodType.CONTRACT) {
        paymentSplit.contract = sum;
      }
    }

    return {
      location: {
        id: location.id,
        name: location.name,
        address: location.address,
        baysCount: location.baysCount,
      },
      period,
      range: {
        start,
        end,
      },
      metrics: {
        clientsTotal,
        newClients,
        clientsWithContacts,
        servicedBookings,
        suspiciousEvents,
        discountedBookings,
        averageCheck,
        revenue,
        blockedClients,
        waitlistWaiting,
        admins,
        washers,
      },
      activeShift: activeShift
        ? {
            id: activeShift.id,
            openedAt: activeShift.openedAt,
            admin: activeShift.admin,
          }
        : null,
      paymentSplit,
      topServices,
    };
  }

  async getChart(rawPeriod?: string) {
    const period = this.parsePeriod(rawPeriod);
    const location = await this.getLocation();
    const now = new Date();

    if (period === 'day') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const points: Array<{
        key: string;
        label: string;
        revenue: number;
        suspiciousEvents: number;
      }> = [];

      for (let hour = 0; hour < 24; hour++) {
        const slotStart = new Date(start);
        slotStart.setHours(hour, 0, 0, 0);

        const slotEnd = new Date(slotStart);
        slotEnd.setHours(slotEnd.getHours() + 1);

        const [revenueAgg, suspiciousEvents] = await Promise.all([
          this.prisma.payment.aggregate({
            where: {
              booking: { locationId: location.id },
              paidAt: { gte: slotStart, lt: slotEnd },
            },
            _sum: { amountRub: true },
          }),
          this.prisma.auditEvent.count({
            where: {
              locationId: location.id,
              createdAt: { gte: slotStart, lt: slotEnd },
              type: { in: this.suspiciousAuditTypes },
            },
          }),
        ]);

        points.push({
          key: `${hour}`,
          label: hour.toString().padStart(2, '0'),
          revenue: revenueAgg._sum.amountRub ?? 0,
          suspiciousEvents,
        });
      }

      return {
        period,
        unit: 'hour',
        points,
      };
    }

    if (period === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      const daysInMonth = new Date(
        now.getFullYear(),
        now.getMonth() + 1,
        0,
      ).getDate();

      const points: Array<{
        key: string;
        label: string;
        revenue: number;
        suspiciousEvents: number;
      }> = [];

      for (let day = 1; day <= daysInMonth; day++) {
        const slotStart = new Date(
          start.getFullYear(),
          start.getMonth(),
          day,
        );
        const slotEnd = new Date(
          start.getFullYear(),
          start.getMonth(),
          day + 1,
        );

        const [revenueAgg, suspiciousEvents] = await Promise.all([
          this.prisma.payment.aggregate({
            where: {
              booking: { locationId: location.id },
              paidAt: { gte: slotStart, lt: slotEnd },
            },
            _sum: { amountRub: true },
          }),
          this.prisma.auditEvent.count({
            where: {
              locationId: location.id,
              createdAt: { gte: slotStart, lt: slotEnd },
              type: { in: this.suspiciousAuditTypes },
            },
          }),
        ]);

        points.push({
          key: `${day}`,
          label: `${day}`,
          revenue: revenueAgg._sum.amountRub ?? 0,
          suspiciousEvents,
        });
      }

      return {
        period,
        unit: 'day',
        points,
      };
    }

    const points: Array<{
      key: string;
      label: string;
      revenue: number;
      suspiciousEvents: number;
    }> = [];

    for (let month = 0; month < 12; month++) {
      const slotStart = new Date(now.getFullYear(), month, 1);
      const slotEnd = new Date(now.getFullYear(), month + 1, 1);

      const [revenueAgg, suspiciousEvents] = await Promise.all([
        this.prisma.payment.aggregate({
          where: {
            booking: { locationId: location.id },
            paidAt: { gte: slotStart, lt: slotEnd },
          },
          _sum: { amountRub: true },
        }),
        this.prisma.auditEvent.count({
          where: {
            locationId: location.id,
            createdAt: { gte: slotStart, lt: slotEnd },
            type: { in: this.suspiciousAuditTypes },
          },
        }),
      ]);

      points.push({
        key: `${month + 1}`,
        label: `${month + 1}`,
        revenue: revenueAgg._sum.amountRub ?? 0,
        suspiciousEvents,
      });
    }

    return {
      period,
      unit: 'month',
      points,
    };
  }

  async getFinance(rawPeriod?: string) {
    const period = this.parsePeriod(rawPeriod);
    const location = await this.getLocation();
    const { start, end } = this.getRange(period);

    const [paymentsByMethod, paymentsByKind] = await Promise.all([
      this.prisma.payment.groupBy({
        by: ['methodType'],
        where: {
          booking: { locationId: location.id },
          paidAt: { gte: start, lt: end },
        },
        _sum: { amountRub: true },
        _count: { _all: true },
      }),

      this.prisma.payment.groupBy({
        by: ['kind'],
        where: {
          booking: { locationId: location.id },
          paidAt: { gte: start, lt: end },
        },
        _sum: { amountRub: true },
        _count: { _all: true },
      }),
    ]);

    const methods = {
      cash: { amountRub: 0, count: 0 },
      card: { amountRub: 0, count: 0 },
      contract: { amountRub: 0, count: 0 },
    };

    for (const row of paymentsByMethod) {
      const payload = {
        amountRub: row._sum.amountRub ?? 0,
        count: row._count._all,
      };

      if (row.methodType === PaymentMethodType.CASH) methods.cash = payload;
      if (row.methodType === PaymentMethodType.CARD) methods.card = payload;
      if (row.methodType === PaymentMethodType.CONTRACT) {
        methods.contract = payload;
      }
    }

    const kinds = paymentsByKind.map((row) => ({
      kind: row.kind,
      amountRub: row._sum.amountRub ?? 0,
      count: row._count._all,
    }));

    return {
      location: {
        id: location.id,
        name: location.name,
      },
      period,
      range: {
        start,
        end,
      },
      methods,
      kinds,
      totals: {
        amountRub:
          methods.cash.amountRub +
          methods.card.amountRub +
          methods.contract.amountRub,
        count:
          methods.cash.count + methods.card.count + methods.contract.count,
      },
    };
  }

  async getEmployees() {
    const location = await this.getLocation();

    const users = await this.prisma.user.findMany({
      where: {
        locationId: location.id,
      },
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        isActive: true,
        createdAt: true,
        mustChangePassword: true,
        lastLoginAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const admins = users.filter((u) => u.role === 'ADMIN');
    const washers = users.filter((u) => u.role === 'WASHER');

    return {
      location: {
        id: location.id,
        name: location.name,
      },
      totals: {
        all: users.length,
        admins: admins.length,
        washers: washers.length,
        active: users.filter((u) => u.isActive).length,
      },
      admins,
      washers,
    };
  }

  async createEmployee(body: {
    name?: string;
    phone?: string;
    role?: string;
    password?: string;
  }) {
    const location = await this.getLocation();

    const name = this.normalizeName(body.name ?? '');
    const phone = this.normalizePhone(body.phone ?? '');
    const role = this.parseEmployeeRole(body.role);
    const password = this.validatePassword(body.password);
    const passwordHash = await this.hashPassword(password);

    const existing = await this.prisma.user.findUnique({
      where: { phone },
      select: { id: true, role: true, locationId: true },
    });

    if (existing) {
      throw new ConflictException('Пользователь с таким телефоном уже существует.');
    }

    const created = await this.prisma.user.create({
      data: {
        name,
        phone,
        role,
        isActive: true,
        passwordHash,
        mustChangePassword: true,
        locationId: location.id,
      },
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        isActive: true,
        mustChangePassword: true,
        lastLoginAt: true,
        createdAt: true,
      },
    });

    return {
      ok: true,
      employee: created,
    };
  }
}