import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AuditType,
  BookingStatus,
  PaymentMethodType,
  Prisma,
  Service,
  ServiceImageKey,
  ServiceKind,
  ServiceLaborCategory,
} from '@prisma/client';
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
      throw new NotFoundException(`Location "${this.locationName}" not found`);
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

  private normalizeDescription(raw?: string): string {
    const value = (raw ?? '').trim();
    if (value.length > 1000) {
      throw new BadRequestException('Описание слишком длинное.');
    }
    return value;
  }

  private parseEmployeeRole(raw?: string): 'ADMIN' | 'WASHER' {
    if (raw === 'ADMIN') return 'ADMIN';
    if (raw === 'WASHER') return 'WASHER';

    throw new BadRequestException('Разрешены только роли ADMIN или WASHER.');
  }

  private parseServiceKind(raw?: string): ServiceKind {
    if (raw === 'BASE') return ServiceKind.BASE;
    if (raw === 'ADDON') return ServiceKind.ADDON;

    throw new BadRequestException('Разрешены только kind BASE или ADDON.');
  }

  private parseServiceImageKey(raw?: string): ServiceImageKey {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'EXTERIOR_WASH':
        return ServiceImageKey.EXTERIOR_WASH;
      case 'FULL_WASH':
        return ServiceImageKey.FULL_WASH;
      case 'WAX':
        return ServiceImageKey.WAX;
      case 'TIRES':
        return ServiceImageKey.TIRES;
      case 'INTERIOR':
        return ServiceImageKey.INTERIOR;
      case 'LEATHER_CARE':
        return ServiceImageKey.LEATHER_CARE;
      default:
        return ServiceImageKey.EXTERIOR_WASH;
    }
  }

  private normalizePriceRub(raw: unknown): number {
    const value = Number(raw);
    if (!Number.isFinite(value)) {
      throw new BadRequestException('priceRub должен быть числом.');
    }
    if (value < 0) {
      throw new BadRequestException('Цена не может быть отрицательной.');
    }
    return Math.round(value);
  }

  private normalizeDurationMin(raw: unknown): number {
    const value = Number(raw);
    if (!Number.isFinite(value)) {
      throw new BadRequestException('durationMin должен быть числом.');
    }
    if (value <= 0) {
      throw new BadRequestException('durationMin должен быть > 0.');
    }
    return Math.round(value);
  }

  private normalizeSortOrder(raw: unknown): number {
    const value = Number(raw);
    if (!Number.isFinite(value)) {
      throw new BadRequestException('sortOrder должен быть числом.');
    }
    return Math.round(value);
  }

  private normalizeBodyType(raw?: string): string {
    const value = (raw ?? '').trim();
    if (!value) {
      throw new BadRequestException('bodyType обязателен.');
    }
    if (value.length > 50) {
      throw new BadRequestException('bodyType слишком длинный.');
    }
    return value;
  }

  private normalizeBodyTypePrices(
    raw?: Array<{
      bodyType?: string;
      priceRub?: number;
    }>,
  ): Array<{
    bodyType: string;
    priceRub: number;
  }> {
    const items = Array.isArray(raw) ? raw : [];

    const normalized = items.map((item) => ({
      bodyType: this.normalizeBodyType(item.bodyType),
      priceRub: this.normalizePriceRub(item.priceRub),
    }));

    const uniqueMap = new Map<string, number>();
    for (const item of normalized) {
      uniqueMap.set(item.bodyType.toLowerCase(), item.priceRub);
    }

    return Array.from(uniqueMap.entries()).map(([bodyTypeKey, priceRub]) => ({
      bodyType: normalized.find(
        (x) => x.bodyType.toLowerCase() === bodyTypeKey,
      )!.bodyType,
      priceRub,
    }));
  }

  private normalizeIncludedAddonIds(raw?: string[]): string[] {
    const items = Array.isArray(raw) ? raw : [];
    const cleaned = items
      .map((x) => (x ?? '').trim())
      .filter((x) => x.length > 0);

    return Array.from(new Set(cleaned));
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

  private async getEmployeeOrThrow(id: string, locationId: string) {
    const employee = await this.prisma.user.findFirst({
      where: {
        id,
        locationId,
        role: { in: ['ADMIN', 'WASHER'] },
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
        locationId: true,
      },
    });

    if (!employee) {
      throw new NotFoundException('Сотрудник не найден.');
    }

    return employee;
  }

  private async getServiceOrThrow(
    id: string,
    locationId: string,
  ): Promise<Service> {
    const service = await this.prisma.service.findFirst({
      where: {
        id,
        locationId,
      },
    });

    if (!service) {
      throw new NotFoundException('Сервис не найден.');
    }

    return service;
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
        role: { in: ['ADMIN', 'WASHER'] },
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
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException(
        'Пользователь с таким телефоном уже существует.',
      );
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

  async updateEmployee(
    id: string,
    body: {
      name?: string;
      phone?: string;
    },
  ) {
    const location = await this.getLocation();
    await this.getEmployeeOrThrow(id, location.id);

    const hasName = typeof body.name === 'string';
    const hasPhone = typeof body.phone === 'string';

    if (!hasName && !hasPhone) {
      throw new BadRequestException('Нужно передать name и/или phone.');
    }

    const data: { name?: string; phone?: string } = {};

    if (hasName) {
      data.name = this.normalizeName(body.name ?? '');
    }

    if (hasPhone) {
      const normalizedPhone = this.normalizePhone(body.phone ?? '');

      const existing = await this.prisma.user.findFirst({
        where: {
          phone: normalizedPhone,
          id: { not: id },
        },
        select: { id: true },
      });

      if (existing) {
        throw new ConflictException(
          'Пользователь с таким телефоном уже существует.',
        );
      }

      data.phone = normalizedPhone;
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data,
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
      employee: updated,
    };
  }

  async toggleEmployee(id: string) {
    const location = await this.getLocation();
    const employee = await this.getEmployeeOrThrow(id, location.id);

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        isActive: !employee.isActive,
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
      employee: updated,
    };
  }

  async resetEmployeePassword(
    id: string,
    body: {
      password?: string;
    },
  ) {
    const location = await this.getLocation();
    await this.getEmployeeOrThrow(id, location.id);

    const password = this.validatePassword(body.password);
    const passwordHash = await this.hashPassword(password);

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        passwordHash,
        mustChangePassword: true,
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
      employee: updated,
    };
  }

  // =======================
  // SERVICES
  // =======================

    // =======================
  // SERVICES
  // =======================

  async createService(body: {
    name?: string;
    description?: string;
    kind?: 'BASE' | 'ADDON';
    imageKey?:
      | 'EXTERIOR_WASH'
      | 'FULL_WASH'
      | 'WAX'
      | 'TIRES'
      | 'INTERIOR'
      | 'LEATHER_CARE';
    priceRub?: number;
    durationMin?: number;
    hasBodyTypePricing?: boolean;
    bodyTypePrices?: Array<{
      bodyType?: string;
      priceRub?: number;
    }>;
    includedAddonIds?: string[];
    isPublished?: boolean;
  }) {
    const location = await this.getLocation();

    const name = this.normalizeName(body.name ?? '');
    const description = this.normalizeDescription(body.description);
    const kind = this.parseServiceKind(body.kind);
    const imageKey = this.parseServiceImageKey(body.imageKey);
    const priceRub = this.normalizePriceRub(body.priceRub);
    const durationMin = this.normalizeDurationMin(body.durationMin);
    const hasBodyTypePricing = body.hasBodyTypePricing === true;
    const bodyTypePrices = this.normalizeBodyTypePrices(body.bodyTypePrices);
    const includedAddonIds = this.normalizeIncludedAddonIds(body.includedAddonIds);
    const isPublished = body.isPublished ?? true;

    if (hasBodyTypePricing && bodyTypePrices.length === 0) {
      throw new BadRequestException(
        'Если включена градация по типу кузова, нужно передать bodyTypePrices.',
      );
    }

    if (kind === ServiceKind.ADDON && includedAddonIds.length > 0) {
      throw new BadRequestException(
        'includedAddonIds можно задавать только для базовой услуги.',
      );
    }

    if (includedAddonIds.length > 0) {
      const addons = await this.prisma.service.findMany({
        where: {
          id: { in: includedAddonIds },
          locationId: location.id,
          kind: ServiceKind.ADDON,
        },
        select: { id: true },
      });

      if (addons.length !== includedAddonIds.length) {
        throw new BadRequestException(
          'Все includedAddonIds должны существовать в текущей локации и быть ADDON.',
        );
      }
    }

    const maxSort = await this.prisma.service.aggregate({
      where: { locationId: location.id, kind },
      _max: { sortOrder: true },
    });

    const sortOrder =
      (maxSort._max.sortOrder ?? (kind === ServiceKind.BASE ? 0 : 100)) + 10;

    const created = await this.prisma.service.create({
      data: {
        locationId: location.id,
        name,
        description,
        kind,
        imageKey,
        isActive: true,
        isPublished,
        sortOrder,
        laborCategory: ServiceLaborCategory.WASH,
        priceRub,
        durationMin,
        hasBodyTypePricing,
        bodyTypePrices: bodyTypePrices.length
          ? {
              create: bodyTypePrices.map((x) => ({
                bodyType: x.bodyType,
                priceRub: x.priceRub,
              })),
            }
          : undefined,
        includedAddonsForBase: includedAddonIds.length
          ? {
              create: includedAddonIds.map((addonServiceId) => ({
                addonService: {
                  connect: { id: addonServiceId },
                },
              })),
            }
          : undefined,
      },
      include: {
        bodyTypePrices: true,
        includedAddonsForBase: {
          include: {
            addonService: true,
          },
        },
      },
    });

    return {
      ok: true,
      service: created,
    };
  }

  async updateService(
    id: string,
    body: {
      name?: string;
      description?: string;
      imageKey?:
        | 'EXTERIOR_WASH'
        | 'FULL_WASH'
        | 'WAX'
        | 'TIRES'
        | 'INTERIOR'
        | 'LEATHER_CARE';
      priceRub?: number;
      durationMin?: number;
      hasBodyTypePricing?: boolean;
      bodyTypePrices?: Array<{
        bodyType?: string;
        priceRub?: number;
      }>;
      includedAddonIds?: string[];
      isPublished?: boolean;
    },
  ) {
    const location = await this.getLocation();
    const existing = await this.getServiceOrThrow(id, location.id);

    const hasName = typeof body.name === 'string';
    const hasDescription = typeof body.description === 'string';
    const hasImageKey = typeof body.imageKey === 'string';
    const hasPriceRub = body.priceRub !== undefined;
    const hasDurationMin = body.durationMin !== undefined;
    const hasHasBodyTypePricing = body.hasBodyTypePricing !== undefined;
    const hasBodyTypePrices = Array.isArray(body.bodyTypePrices);
    const hasIncludedAddonIds = Array.isArray(body.includedAddonIds);
    const hasIsPublished = body.isPublished !== undefined;

    if (
      !hasName &&
      !hasDescription &&
      !hasImageKey &&
      !hasPriceRub &&
      !hasDurationMin &&
      !hasHasBodyTypePricing &&
      !hasBodyTypePrices &&
      !hasIncludedAddonIds &&
      !hasIsPublished
    ) {
      throw new BadRequestException(
        'Нужно передать хотя бы одно поле для обновления.',
      );
    }

    const data: Prisma.ServiceUpdateInput = {};

    if (hasName) {
      data.name = this.normalizeName(body.name ?? '');
    }

    if (hasDescription) {
      data.description = this.normalizeDescription(body.description);
    }

    if (hasImageKey) {
      data.imageKey = this.parseServiceImageKey(body.imageKey);
    }

    if (hasPriceRub) {
      data.priceRub = this.normalizePriceRub(body.priceRub);
    }

    if (hasDurationMin) {
      data.durationMin = this.normalizeDurationMin(body.durationMin);
    }

    if (hasHasBodyTypePricing) {
      data.hasBodyTypePricing = body.hasBodyTypePricing === true;
    }

    if (hasIsPublished) {
      data.isPublished = body.isPublished === true;
    }

    if (hasIncludedAddonIds) {
      if (existing.kind !== ServiceKind.BASE) {
        throw new BadRequestException(
          'includedAddonIds можно задавать только для базовой услуги.',
        );
      }

      const includedAddonIds = this.normalizeIncludedAddonIds(
        body.includedAddonIds,
      );

      if (includedAddonIds.length > 0) {
        const addons = await this.prisma.service.findMany({
          where: {
            id: { in: includedAddonIds },
            locationId: location.id,
            kind: ServiceKind.ADDON,
          },
          select: { id: true },
        });

        if (addons.length !== includedAddonIds.length) {
          throw new BadRequestException(
            'Все includedAddonIds должны существовать в текущей локации и быть ADDON.',
          );
        }
      }

      await this.prisma.serviceIncludedAddon.deleteMany({
        where: { baseServiceId: id },
      });

      if (includedAddonIds.length > 0) {
        await this.prisma.serviceIncludedAddon.createMany({
          data: includedAddonIds.map((addonServiceId) => ({
            baseServiceId: id,
            addonServiceId,
          })),
        });
      }
    }

    if (hasBodyTypePrices || hasHasBodyTypePricing) {
      const hasBodyTypePricing =
        body.hasBodyTypePricing !== undefined
          ? body.hasBodyTypePricing === true
          : existing.hasBodyTypePricing;

      const bodyTypePrices = hasBodyTypePrices
        ? this.normalizeBodyTypePrices(body.bodyTypePrices)
        : null;

      if (
        hasBodyTypePricing &&
        hasBodyTypePrices &&
        bodyTypePrices!.length === 0
      ) {
        throw new BadRequestException(
          'Если включена градация по типу кузова, нужно передать bodyTypePrices.',
        );
      }

      if (hasBodyTypePrices) {
        await this.prisma.serviceBodyTypePrice.deleteMany({
          where: { serviceId: id },
        });

        if (bodyTypePrices && bodyTypePrices.length > 0) {
          await this.prisma.serviceBodyTypePrice.createMany({
            data: bodyTypePrices.map((x) => ({
              serviceId: id,
              bodyType: x.bodyType,
              priceRub: x.priceRub,
            })),
          });
        }
      }
    }

    const updated = await this.prisma.service.update({
      where: { id },
      data,
      include: {
        bodyTypePrices: true,
        includedAddonsForBase: {
          include: {
            addonService: true,
          },
        },
      },
    });

    return {
      ok: true,
      service: updated,
    };
  }

  async toggleService(id: string) {
    const location = await this.getLocation();
    const existing = await this.getServiceOrThrow(id, location.id);

    const updated = await this.prisma.service.update({
      where: { id },
      data: {
        isActive: !existing.isActive,
      },
      include: {
        bodyTypePrices: true,
        includedAddonsForBase: {
          include: {
            addonService: true,
          },
        },
      },
    });

    return {
      ok: true,
      service: updated,
    };
  }
}