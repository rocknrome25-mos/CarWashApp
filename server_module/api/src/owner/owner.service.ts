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

type ContactsConfig = {
  title?: string;
  address?: string;
  phone?: string;
  telegram?: string;
  whatsapp?: string;
  navigatorLink?: string;
  mapsLink?: string;
};

type OwnerSettingsConfig = {
  communication: {
    washStartTemplate: string;
    washFinishTemplate: string;
    campaigns: {
      promotionsEnabled: boolean;
      discountsEnabled: boolean;
      holidayGreetingsEnabled: boolean;
    };
  };
  monitoring: {
    suspiciousAuditTypes: AuditType[];
    notifyPhone: string;
    notifyTelegram: string;
    notifyPush: boolean;
  };
};

type SettingsLocation = {
  id: string;
  tenantId: string;
  name: string;
  address: string | null;
  colorHex: string;
  baysCount: number;
  phone: string | null;
  telegram: string | null;
  whatsapp: string | null;
  navigatorLink: string | null;
};

type CompensationSettingsConfig = {
  washerBasePercent: number;
  washerAddonPercent: number;
  adminBaseSalaryRub: number;
  adminBasePercent: number;
  adminAddonPercent: number;
  adminUpsellPercent: number;
};

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

  private parsePositiveLimit(raw?: string, fallback = 50, max = 200): number {
    const value = Number(raw);
    if (!Number.isFinite(value) || value <= 0) {
      return fallback;
    }
    return Math.min(Math.round(value), max);
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

  private async getLocationForSettings(): Promise<SettingsLocation> {
    const location = await this.prisma.location.findUnique({
      where: { name: this.locationName },
      select: {
        id: true,
        tenantId: true,
        name: true,
        address: true,
        colorHex: true,
        baysCount: true,
        phone: true,
        telegram: true,
        whatsapp: true,
        navigatorLink: true,
      },
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

  private getDaysInMonth(date: Date): number {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  }

  private getAdminSalaryForPeriod(
    monthlySalaryRub: number,
    period: Period,
    rangeStart: Date,
  ): number {
    if (monthlySalaryRub <= 0) return 0;

    if (period === 'month') {
      return monthlySalaryRub;
    }

    if (period === 'year') {
      return monthlySalaryRub * 12;
    }

    const daysInMonth = this.getDaysInMonth(rangeStart);
    return Math.round(monthlySalaryRub / daysInMonth);
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

  private readonly suspiciousAuditOptions: Array<{
    key: AuditType;
    label: string;
  }> = [
    { key: AuditType.BOOKING_CHANGE_SERVICE, label: 'Замена услуги' },
    { key: AuditType.BOOKING_DISCOUNT, label: 'Изменение цены / скидка' },
    { key: AuditType.BOOKING_CHANGE_BODYTYPE, label: 'Изменение типа кузова' },
    { key: AuditType.BOOKING_DELETE, label: 'Отмена бронирования' },
    { key: AuditType.BAY_OPEN, label: 'Открытие поста' },
    { key: AuditType.BAY_CLOSE, label: 'Закрытие поста' },
    { key: AuditType.WAITLIST_DELETE, label: 'Отмена waitlist' },
  ];

  private auditTypeLabel(type: AuditType | string): string {
    const found = this.suspiciousAuditOptions.find((x) => x.key === type);
    return found?.label ?? String(type);
  }

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

  private normalizeOptionalPhone(raw?: string): string {
    const value = (raw ?? '').trim();
    if (!value) return '';
    return this.normalizePhone(value);
  }

  private normalizeTelegramHandle(raw?: string): string {
    const value = (raw ?? '').trim();
    if (!value) return '';
    return value.startsWith('@') ? value : `@${value}`;
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

  private normalizeOptionalText(raw?: string, max = 2000): string {
    const value = (raw ?? '').trim();
    if (value.length > max) {
      throw new BadRequestException('Текст слишком длинный.');
    }
    return value;
  }

  private normalizePercent(raw: unknown, fieldName: string): number {
    const value = Number(raw);
    if (!Number.isFinite(value)) {
      throw new BadRequestException(`${fieldName} должен быть числом.`);
    }
    if (value < 0 || value > 100) {
      throw new BadRequestException(
        `${fieldName} должен быть в диапазоне 0..100.`,
      );
    }
    return Math.round(value);
  }

  private normalizeMoneyRub(raw: unknown, fieldName: string): number {
    const value = Number(raw);
    if (!Number.isFinite(value)) {
      throw new BadRequestException(`${fieldName} должен быть числом.`);
    }
    if (value < 0) {
      throw new BadRequestException(
        `${fieldName} не может быть отрицательным.`,
      );
    }
    return Math.round(value);
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

  private asObject(value: unknown): Record<string, any> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      return {};
    }
    return value as Record<string, any>;
  }

  private buildDefaultContacts(location: SettingsLocation): ContactsConfig {
    return {
      title: (location.name ?? '').trim(),
      address: (location.address ?? '').trim(),
      phone: (location.phone ?? '').trim(),
      telegram: this.normalizeTelegramHandle(location.telegram ?? ''),
      whatsapp: (location.whatsapp ?? '').trim(),
      navigatorLink: (location.navigatorLink ?? '').trim(),
      mapsLink: (location.navigatorLink ?? '').trim(),
    };
  }

  private normalizeContactsParams(
    raw: unknown,
    defaults: ContactsConfig,
  ): ContactsConfig {
    const obj = this.asObject(raw);

    const title = this.normalizeOptionalText(
      typeof obj.title === 'string' ? obj.title : defaults.title ?? '',
      150,
    );
    const address = this.normalizeOptionalText(
      typeof obj.address === 'string' ? obj.address : defaults.address ?? '',
      300,
    );
    const phone = this.normalizeOptionalPhone(
      typeof obj.phone === 'string' ? obj.phone : defaults.phone ?? '',
    );
    const telegram = this.normalizeTelegramHandle(
      typeof obj.telegram === 'string' ? obj.telegram : defaults.telegram ?? '',
    );
    const whatsapp = this.normalizeOptionalPhone(
      typeof obj.whatsapp === 'string' ? obj.whatsapp : defaults.whatsapp ?? '',
    );
    const navigatorLink = this.normalizeOptionalText(
      typeof obj.navigatorLink === 'string'
        ? obj.navigatorLink
        : defaults.navigatorLink ?? '',
      500,
    );
    const mapsLink = this.normalizeOptionalText(
      typeof obj.mapsLink === 'string' ? obj.mapsLink : defaults.mapsLink ?? '',
      500,
    );

    return {
      title,
      address,
      phone,
      telegram,
      whatsapp,
      navigatorLink,
      mapsLink,
    };
  }

  private getDefaultOwnerSettings(
    contacts: ContactsConfig,
  ): OwnerSettingsConfig {
    return {
      communication: {
        washStartTemplate:
          'Ваш автомобиль принят в мойку. Мы сообщим, когда работа будет завершена.',
        washFinishTemplate:
          'Мойка завершена. Ваш автомобиль готов к выдаче. Спасибо, что выбрали нас.',
        campaigns: {
          promotionsEnabled: false,
          discountsEnabled: false,
          holidayGreetingsEnabled: false,
        },
      },
      monitoring: {
        suspiciousAuditTypes: [...this.suspiciousAuditTypes],
        notifyPhone: contacts.phone ?? '',
        notifyTelegram: contacts.telegram ?? '',
        notifyPush: true,
      },
    };
  }

  private getDefaultCompensationSettings(): CompensationSettingsConfig {
    return {
      washerBasePercent: 30,
      washerAddonPercent: 15,
      adminBaseSalaryRub: 0,
      adminBasePercent: 10,
      adminAddonPercent: 10,
      adminUpsellPercent: 10,
    };
  }

  private normalizeSuspiciousAuditTypes(raw?: string[]): AuditType[] {
    const allowed = new Set(this.suspiciousAuditOptions.map((x) => x.key));
    const items = Array.isArray(raw) ? raw : [];

    const normalized = items
      .map((x) => (x ?? '').toString().trim())
      .filter((x) => x.length > 0)
      .map((x) => x as AuditType)
      .filter((x) => allowed.has(x));

    return Array.from(new Set(normalized));
  }

  private normalizeOwnerSettings(
    raw: unknown,
    defaults: OwnerSettingsConfig,
  ): OwnerSettingsConfig {
    const obj = this.asObject(raw);
    const communication = this.asObject(obj.communication);
    const campaigns = this.asObject(communication.campaigns);
    const monitoring = this.asObject(obj.monitoring);

    const suspiciousAuditTypes = this.normalizeSuspiciousAuditTypes(
      Array.isArray(monitoring.suspiciousAuditTypes)
        ? monitoring.suspiciousAuditTypes.map(String)
        : defaults.monitoring.suspiciousAuditTypes,
    );

    return {
      communication: {
        washStartTemplate: this.normalizeOptionalText(
          typeof communication.washStartTemplate === 'string'
            ? communication.washStartTemplate
            : defaults.communication.washStartTemplate,
          1000,
        ),
        washFinishTemplate: this.normalizeOptionalText(
          typeof communication.washFinishTemplate === 'string'
            ? communication.washFinishTemplate
            : defaults.communication.washFinishTemplate,
          1000,
        ),
        campaigns: {
          promotionsEnabled:
            typeof campaigns.promotionsEnabled === 'boolean'
              ? campaigns.promotionsEnabled
              : defaults.communication.campaigns.promotionsEnabled,
          discountsEnabled:
            typeof campaigns.discountsEnabled === 'boolean'
              ? campaigns.discountsEnabled
              : defaults.communication.campaigns.discountsEnabled,
          holidayGreetingsEnabled:
            typeof campaigns.holidayGreetingsEnabled === 'boolean'
              ? campaigns.holidayGreetingsEnabled
              : defaults.communication.campaigns.holidayGreetingsEnabled,
        },
      },
      monitoring: {
        suspiciousAuditTypes:
          suspiciousAuditTypes.length > 0
            ? suspiciousAuditTypes
            : [...defaults.monitoring.suspiciousAuditTypes],
        notifyPhone: this.normalizeOptionalPhone(
          typeof monitoring.notifyPhone === 'string'
            ? monitoring.notifyPhone
            : defaults.monitoring.notifyPhone,
        ),
        notifyTelegram: this.normalizeTelegramHandle(
          typeof monitoring.notifyTelegram === 'string'
            ? monitoring.notifyTelegram
            : defaults.monitoring.notifyTelegram,
        ),
        notifyPush:
          typeof monitoring.notifyPush === 'boolean'
            ? monitoring.notifyPush
            : defaults.monitoring.notifyPush,
      },
    };
  }

  private async readSettingsSnapshot(location: SettingsLocation) {
    const features = await this.prisma.tenantFeature.findMany({
      where: {
        tenantId: location.tenantId,
        key: { in: ['CONTACTS', 'OWNER_SETTINGS'] },
      },
      select: {
        key: true,
        enabled: true,
        params: true,
      },
    });

    const contactsFeature = features.find(
      (x) => x.key === 'CONTACTS' && x.enabled === true,
    );
    const ownerFeature = features.find(
      (x) => x.key === 'OWNER_SETTINGS' && x.enabled === true,
    );

    const defaultContacts = this.buildDefaultContacts(location);
    const contacts = this.normalizeContactsParams(
      contactsFeature?.params,
      defaultContacts,
    );

    const defaultOwnerSettings = this.getDefaultOwnerSettings(contacts);
    const ownerSettings = this.normalizeOwnerSettings(
      ownerFeature?.params,
      defaultOwnerSettings,
    );

    return {
      contacts,
      ownerSettings,
    };
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

  private async getOwnerUserOrThrow(locationId: string) {
    const owner = await this.prisma.user.findFirst({
      where: {
        locationId,
        role: 'OWNER',
      },
      select: {
        id: true,
        name: true,
        phone: true,
        isActive: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    if (!owner) {
      throw new NotFoundException(
        'OWNER пользователь для этой локации не найден.',
      );
    }

    return owner;
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

    const compensationDefaults = this.getDefaultCompensationSettings();

    const compensation = await this.prisma.locationCompensationSettings.findUnique({
      where: { locationId: location.id },
      select: {
        washerBasePercent: true,
        washerAddonPercent: true,
        adminBaseSalaryRub: true,
      },
    });

    const washerBasePercent =
      compensation?.washerBasePercent ?? compensationDefaults.washerBasePercent;
    const washerAddonPercent =
      compensation?.washerAddonPercent ?? compensationDefaults.washerAddonPercent;
    const defaultAdminBaseSalaryRub =
      compensation?.adminBaseSalaryRub ??
      compensationDefaults.adminBaseSalaryRub;

    const activeAdmins = await this.prisma.user.findMany({
      where: {
        locationId: location.id,
        role: 'ADMIN',
        isActive: true,
      },
      select: {
        id: true,
        compensationProfile: {
          select: {
            adminBaseSalaryRub: true,
            isActive: true,
          },
        },
      },
    });

    const activeAdminIds = activeAdmins.map((x) => x.id);

    const [
      shiftWashers,
      adminSaleBookings,
      adminUpsellAddons,
      allUpsellAddons,
    ] = await Promise.all([
      this.prisma.shiftWasher.findMany({
        where: {
          shift: {
            locationId: location.id,
            openedAt: { gte: start, lt: end },
          },
        },
        select: {
          washerId: true,
          shiftId: true,
          bayId: true,
          percentWash: true,
          percentBaseService: true,
          percentAddon: true,
        },
      }),

      activeAdminIds.length === 0
        ? []
        : this.prisma.booking.findMany({
            where: {
              locationId: location.id,
              status: BookingStatus.COMPLETED,
              dateTime: { gte: start, lt: end },
              createdByUserId: { in: activeAdminIds },
              isAdminSale: true,
            },
            select: {
              id: true,
              createdByUserId: true,
              servicePriceRubSnapshot: true,
              adminBaseBonusRubSnapshot: true,
              service: {
                select: {
                  priceRub: true,
                },
              },
              addons: {
                select: {
                  qty: true,
                  priceRubSnapshot: true,
                  isUpsell: true,
                  adminAddonBonusRubSnapshot: true,
                },
              },
            },
          }),

      activeAdminIds.length === 0
        ? []
        : this.prisma.bookingAddon.findMany({
            where: {
              isUpsell: true,
              upsoldByUserId: { in: activeAdminIds },
              booking: {
                locationId: location.id,
                status: BookingStatus.COMPLETED,
                dateTime: { gte: start, lt: end },
              },
            },
            select: {
              id: true,
              upsoldByUserId: true,
              qty: true,
              priceRubSnapshot: true,
              upsellBonusRubSnapshot: true,
            },
          }),

      this.prisma.bookingAddon.findMany({
        where: {
          isUpsell: true,
          booking: {
            locationId: location.id,
            status: BookingStatus.COMPLETED,
            dateTime: { gte: start, lt: end },
          },
        },
        select: {
          qty: true,
          priceRubSnapshot: true,
        },
      }),
    ]);

    const shiftIdsForWashers = Array.from(
      new Set(shiftWashers.map((x) => x.shiftId)),
    );

    const washerBookings =
      shiftIdsForWashers.length === 0
        ? []
        : await this.prisma.booking.findMany({
            where: {
              locationId: location.id,
              status: BookingStatus.COMPLETED,
              shiftId: { in: shiftIdsForWashers },
              dateTime: { gte: start, lt: end },
            },
            select: {
              id: true,
              shiftId: true,
              bayId: true,
              servicePriceRubSnapshot: true,
              service: {
                select: {
                  priceRub: true,
                },
              },
              addons: {
                select: {
                  qty: true,
                  priceRubSnapshot: true,
                },
              },
            },
          });

    const washerAssignmentMap = new Map<
      string,
      {
        percentBaseService: number | null;
        percentAddon: number | null;
        percentWash: number | null;
      }
    >();

    for (const assignment of shiftWashers) {
      washerAssignmentMap.set(`${assignment.shiftId}:${assignment.bayId}`, {
        percentBaseService: assignment.percentBaseService,
        percentAddon: assignment.percentAddon,
        percentWash: assignment.percentWash,
      });
    }

    let washersExpense = 0;

    for (const booking of washerBookings) {
      if (!booking.shiftId) continue;

      const assignment = washerAssignmentMap.get(
        `${booking.shiftId}:${booking.bayId}`,
      );
      if (!assignment) continue;

      const basePrice =
        booking.servicePriceRubSnapshot ?? booking.service?.priceRub ?? 0;

      const addonTotal = booking.addons.reduce((sum, addon) => {
        const qty = addon.qty ?? 1;
        const price = addon.priceRubSnapshot ?? 0;
        return sum + qty * price;
      }, 0);

      const basePercent =
        assignment.percentBaseService ??
        assignment.percentWash ??
        washerBasePercent;
      const addonPercent = assignment.percentAddon ?? washerAddonPercent;

      washersExpense += Math.round((basePrice * basePercent) / 100);
      washersExpense += Math.round((addonTotal * addonPercent) / 100);
    }

    let adminSalesRevenueRub = 0;
    let adminBonusExpense = 0;
    let adminUpsellRevenueRub = 0;
    let adminUpsellBonusExpense = 0;

    for (const booking of adminSaleBookings) {
      const baseRevenue =
        booking.servicePriceRubSnapshot ?? booking.service?.priceRub ?? 0;

      let addonRevenue = 0;
      let addonBonus = 0;

      for (const addon of booking.addons) {
        if (addon.isUpsell === true) continue;

        const qty = addon.qty ?? 1;
        const price = addon.priceRubSnapshot ?? 0;

        addonRevenue += qty * price;
        addonBonus += addon.adminAddonBonusRubSnapshot ?? 0;
      }

      adminSalesRevenueRub += baseRevenue + addonRevenue;
      adminBonusExpense +=
        (booking.adminBaseBonusRubSnapshot ?? 0) + addonBonus;
    }

    for (const addon of adminUpsellAddons) {
      const qty = addon.qty ?? 1;
      const price = addon.priceRubSnapshot ?? 0;

      adminUpsellRevenueRub += qty * price;
      adminUpsellBonusExpense += addon.upsellBonusRubSnapshot ?? 0;
    }

    adminBonusExpense += adminUpsellBonusExpense;

    let adminSalaryExpense = 0;

    for (const admin of activeAdmins) {
      const salaryOverride =
        admin.compensationProfile?.isActive === true
          ? admin.compensationProfile.adminBaseSalaryRub
          : null;

      const monthlySalaryRub =
        salaryOverride ?? defaultAdminBaseSalaryRub;

      adminSalaryExpense += this.getAdminSalaryForPeriod(
        monthlySalaryRub,
        period,
        start,
      );
    }

    const adminExpense = adminBonusExpense + adminSalaryExpense;
    const expenses = washersExpense + adminExpense;
    const profit = revenue - expenses;
    const upsellRevenueRub = allUpsellAddons.reduce((sum, addon) => {
      const qty = addon.qty ?? 1;
      const price = addon.priceRubSnapshot ?? 0;
      return sum + qty * price;
    }, 0);

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
        expenses,
        profit,
        employeeExpenseRub: expenses,
        washerExpenseRub: washersExpense,
        adminExpenseRub: adminExpense,
        adminBonusExpenseRub: adminBonusExpense,
        adminSalaryExpenseRub: adminSalaryExpense,
        adminSalesRevenueRub,
        adminUpsellRevenueRub,
        upsellRevenueRub,
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

  async getSuspiciousEvents(params: {
    period?: string;
    type?: string;
    userId?: string;
    limit?: string;
  }) {
    const period = this.parsePeriod(params.period);
    const location = await this.getLocation();
    const { start, end } = this.getRange(period);
    const limit = this.parsePositiveLimit(params.limit, 50, 200);

    const requestedType = (params.type ?? '').trim() as AuditType;
    const filterType = this.suspiciousAuditTypes.includes(requestedType)
      ? requestedType
      : undefined;
    const filterUserId = (params.userId ?? '').trim() || undefined;

    const where: Prisma.AuditEventWhereInput = {
      locationId: location.id,
      createdAt: { gte: start, lt: end },
      type: filterType ? filterType : { in: this.suspiciousAuditTypes },
      ...(filterUserId ? { userId: filterUserId } : {}),
    };

    const [events, typeGroups, userGroups] = await Promise.all([
      this.prisma.auditEvent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: limit,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              phone: true,
              role: true,
            },
          },
        },
      }),
      this.prisma.auditEvent.groupBy({
        by: ['type'],
        where,
        _count: { _all: true },
      }),
      this.prisma.auditEvent.groupBy({
        by: ['userId'],
        where,
        _count: { _all: true },
      }),
    ]);

    const userIds = userGroups
      .map((x) => x.userId)
      .filter((x): x is string => !!x);

    const users =
      userIds.length === 0
        ? []
        : await this.prisma.user.findMany({
            where: { id: { in: userIds } },
            select: {
              id: true,
              name: true,
              phone: true,
              role: true,
            },
          });

    const byType = typeGroups
      .map((row) => ({
        type: row.type,
        label: this.auditTypeLabel(row.type),
        count: row._count._all,
      }))
      .sort((a, b) => b.count - a.count);

    const byUser = userGroups
      .map((row) => {
        const user = users.find((u) => u.id === row.userId);
        return {
          userId: row.userId,
          userName: user?.name ?? 'Система / не указан',
          phone: user?.phone ?? '',
          role: user?.role ?? null,
          count: row._count._all,
        };
      })
      .sort((a, b) => b.count - a.count);

    return {
      location: {
        id: location.id,
        name: location.name,
      },
      period,
      range: { start, end },
      filters: {
        type: filterType ?? null,
        userId: filterUserId ?? null,
        limit,
      },
      options: {
        suspiciousAuditTypes: this.suspiciousAuditOptions,
      },
      totals: {
        total: events.length,
      },
      byType,
      byUser,
      events: events.map((event) => ({
        id: event.id,
        createdAt: event.createdAt,
        type: event.type,
        typeLabel: this.auditTypeLabel(event.type),
        reason: event.reason ?? '',
        locationId: event.locationId,
        shiftId: event.shiftId,
        bookingId: event.bookingId,
        clientId: event.clientId,
        payload: event.payload ?? null,
        user: event.user
          ? {
              id: event.user.id,
              name: event.user.name ?? 'Без имени',
              phone: event.user.phone,
              role: event.user.role,
            }
          : null,
      })),
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

  async getEmployeeAnalytics(rawPeriod?: string) {
    const period = this.parsePeriod(rawPeriod);
    const location = await this.getLocation();
    const { start, end } = this.getRange(period);
    const compensationDefaults = this.getDefaultCompensationSettings();

    const employees = await this.prisma.user.findMany({
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
        lastLoginAt: true,
      },
      orderBy: [{ role: 'asc' }, { name: 'asc' }],
    });

    const adminIds = employees
      .filter((e) => e.role === 'ADMIN')
      .map((e) => e.id);

    const washerIds = employees
      .filter((e) => e.role === 'WASHER')
      .map((e) => e.id);

    const [
      shiftGroups,
      discountGroups,
      suspiciousGroups,
      bookingGroups,
      washerAssignments,
      adminSaleBookings,
      adminUpsellAddons,
      compensationSettings,
      adminCompensationProfiles,
    ] = await Promise.all([
      adminIds.length === 0
        ? []
        : this.prisma.shift.groupBy({
            by: ['adminId'],
            where: {
              locationId: location.id,
              openedAt: { gte: start, lt: end },
            },
            _count: { _all: true },
          }),

      adminIds.length === 0
        ? []
        : this.prisma.auditEvent.groupBy({
            by: ['userId'],
            where: {
              locationId: location.id,
              createdAt: { gte: start, lt: end },
              type: AuditType.BOOKING_DISCOUNT,
              userId: { in: adminIds },
            },
            _count: { _all: true },
          }),

      adminIds.length === 0
        ? []
        : this.prisma.auditEvent.groupBy({
            by: ['userId'],
            where: {
              locationId: location.id,
              createdAt: { gte: start, lt: end },
              type: { in: this.suspiciousAuditTypes },
              userId: { in: adminIds },
            },
            _count: { _all: true },
          }),

      adminIds.length === 0
        ? []
        : this.prisma.booking.groupBy({
            by: ['shiftId'],
            where: {
              locationId: location.id,
              dateTime: { gte: start, lt: end },
              shiftId: { not: null },
            },
            _count: { _all: true },
          }),

      washerIds.length === 0
        ? []
        : this.prisma.shiftWasher.findMany({
            where: {
              washerId: { in: washerIds },
              shift: {
                locationId: location.id,
                openedAt: { gte: start, lt: end },
              },
            },
            select: {
              washerId: true,
              shiftId: true,
              bayId: true,
              percentWash: true,
              percentBaseService: true,
              percentAddon: true,
            },
          }),

      adminIds.length === 0
        ? []
        : this.prisma.booking.findMany({
            where: {
              locationId: location.id,
              status: BookingStatus.COMPLETED,
              dateTime: { gte: start, lt: end },
              createdByUserId: { in: adminIds },
              isAdminSale: true,
            },
            select: {
              id: true,
              createdByUserId: true,
              servicePriceRubSnapshot: true,
              adminBaseBonusRubSnapshot: true,
              service: {
                select: {
                  priceRub: true,
                },
              },
              addons: {
                select: {
                  qty: true,
                  priceRubSnapshot: true,
                  isUpsell: true,
                  adminAddonBonusRubSnapshot: true,
                },
              },
            },
          }),

      adminIds.length === 0
        ? []
        : this.prisma.bookingAddon.findMany({
            where: {
              isUpsell: true,
              upsoldByUserId: { in: adminIds },
              booking: {
                locationId: location.id,
                status: BookingStatus.COMPLETED,
                dateTime: { gte: start, lt: end },
              },
            },
            select: {
              id: true,
              upsoldByUserId: true,
              qty: true,
              priceRubSnapshot: true,
              upsellBonusRubSnapshot: true,
            },
          }),

      this.prisma.locationCompensationSettings.findUnique({
        where: { locationId: location.id },
        select: {
          adminBaseSalaryRub: true,
        },
      }),

      adminIds.length === 0
        ? []
        : this.prisma.userCompensationProfile.findMany({
            where: {
              userId: { in: adminIds },
              isActive: true,
            },
            select: {
              userId: true,
              adminBaseSalaryRub: true,
            },
          }),
    ]);

    const shiftIds = bookingGroups
      .map((x) => x.shiftId)
      .filter((x): x is string => !!x);

    const shifts =
      shiftIds.length === 0
        ? []
        : await this.prisma.shift.findMany({
            where: {
              id: { in: shiftIds },
            },
            select: {
              id: true,
              adminId: true,
            },
          });

    const bookingsHandledMap = new Map<string, number>();
    for (const group of bookingGroups) {
      const shift = shifts.find((s) => s.id === group.shiftId);
      if (!shift?.adminId) continue;

      bookingsHandledMap.set(
        shift.adminId,
        (bookingsHandledMap.get(shift.adminId) ?? 0) + group._count._all,
      );
    }

    const washerShiftIds = Array.from(
      new Set(washerAssignments.map((x) => x.shiftId)),
    );

    const washerBookings =
      washerShiftIds.length === 0
        ? []
        : await this.prisma.booking.findMany({
            where: {
              locationId: location.id,
              status: BookingStatus.COMPLETED,
              shiftId: { in: washerShiftIds },
              dateTime: { gte: start, lt: end },
            },
            select: {
              id: true,
              shiftId: true,
              bayId: true,
              servicePriceRubSnapshot: true,
              service: {
                select: {
                  priceRub: true,
                },
              },
              addons: {
                select: {
                  qty: true,
                  priceRubSnapshot: true,
                },
              },
            },
          });

    const washerShiftSetMap = new Map<string, Set<string>>();
    const washerCarsServicedMap = new Map<string, number>();
    const washerEarnedRubMap = new Map<string, number>();

    for (const assignment of washerAssignments) {
      const shiftSet =
        washerShiftSetMap.get(assignment.washerId) ?? new Set<string>();
      shiftSet.add(assignment.shiftId);
      washerShiftSetMap.set(assignment.washerId, shiftSet);
    }

    const assignmentByShiftBay = new Map<
      string,
      {
        washerId: string;
        percentBaseService: number;
        percentAddon: number;
      }
    >();

    for (const assignment of washerAssignments) {
      const key = `${assignment.shiftId}:${assignment.bayId}`;

      assignmentByShiftBay.set(key, {
        washerId: assignment.washerId,
        percentBaseService:
          assignment.percentBaseService ?? assignment.percentWash ?? 0,
        percentAddon: assignment.percentAddon ?? 0,
      });
    }

    for (const booking of washerBookings) {
      const shiftId = booking.shiftId;
      if (!shiftId) continue;

      const key = `${shiftId}:${booking.bayId}`;
      const assignment = assignmentByShiftBay.get(key);
      if (!assignment) continue;

      const basePrice =
        booking.servicePriceRubSnapshot ?? booking.service?.priceRub ?? 0;

      const addonTotal = booking.addons.reduce((sum, addon) => {
        const qty = addon.qty ?? 1;
        const price = addon.priceRubSnapshot ?? 0;
        return sum + qty * price;
      }, 0);

      const baseEarned = Math.round(
        (basePrice * assignment.percentBaseService) / 100,
      );
      const addonEarned = Math.round(
        (addonTotal * assignment.percentAddon) / 100,
      );

      washerCarsServicedMap.set(
        assignment.washerId,
        (washerCarsServicedMap.get(assignment.washerId) ?? 0) + 1,
      );

      washerEarnedRubMap.set(
        assignment.washerId,
        (washerEarnedRubMap.get(assignment.washerId) ?? 0) +
          baseEarned +
          addonEarned,
      );
    }

    const adminSalesRevenueRubMap = new Map<string, number>();
    const adminBonusRubMap = new Map<string, number>();
    const adminSalaryRubMap = new Map<string, number>();

    const baseMonthlySalary =
      compensationSettings?.adminBaseSalaryRub ??
      compensationDefaults.adminBaseSalaryRub;

    for (const employee of employees) {
      if (employee.role !== 'ADMIN') continue;

      const profile = adminCompensationProfiles.find(
        (x) => x.userId === employee.id,
      );

      const monthlySalaryRub =
        profile?.adminBaseSalaryRub ?? baseMonthlySalary;

      const salaryRub = this.getAdminSalaryForPeriod(
        monthlySalaryRub,
        period,
        start,
      );

      adminSalaryRubMap.set(employee.id, salaryRub);
    }

    for (const booking of adminSaleBookings) {
      const adminId = booking.createdByUserId;
      if (!adminId) continue;

      const baseRevenue =
        booking.servicePriceRubSnapshot ?? booking.service?.priceRub ?? 0;

      let addonRevenue = 0;
      let addonBonus = 0;

      for (const addon of booking.addons) {
        if (addon.isUpsell === true) continue;
        const qty = addon.qty ?? 1;
        const price = addon.priceRubSnapshot ?? 0;
        addonRevenue += qty * price;
        addonBonus += addon.adminAddonBonusRubSnapshot ?? 0;
      }

      const totalRevenue = baseRevenue + addonRevenue;
      const totalBonus =
        (booking.adminBaseBonusRubSnapshot ?? 0) + addonBonus;

      adminSalesRevenueRubMap.set(
        adminId,
        (adminSalesRevenueRubMap.get(adminId) ?? 0) + totalRevenue,
      );

      adminBonusRubMap.set(
        adminId,
        (adminBonusRubMap.get(adminId) ?? 0) + totalBonus,
      );
    }

    for (const addon of adminUpsellAddons) {
      const adminId = addon.upsoldByUserId;
      if (!adminId) continue;

      const qty = addon.qty ?? 1;
      const price = addon.priceRubSnapshot ?? 0;
      const revenue = qty * price;
      const bonus = addon.upsellBonusRubSnapshot ?? 0;

      adminSalesRevenueRubMap.set(
        adminId,
        (adminSalesRevenueRubMap.get(adminId) ?? 0) + revenue,
      );

      adminBonusRubMap.set(
        adminId,
        (adminBonusRubMap.get(adminId) ?? 0) + bonus,
      );
    }

    const analytics = employees.map((employee) => {
      const adminShiftsOpened =
        shiftGroups.find((x) => x.adminId === employee.id)?._count._all ?? 0;

      const discountsGiven =
        discountGroups.find((x) => x.userId === employee.id)?._count._all ?? 0;

      const suspiciousActions =
        employee.role === 'ADMIN'
          ? (suspiciousGroups.find((x) => x.userId === employee.id)?._count
              ._all ?? 0)
          : 0;

      const bookingsHandled = bookingsHandledMap.get(employee.id) ?? 0;

      const washerShiftsWorked = washerShiftSetMap.get(employee.id)?.size ?? 0;
      const carsServiced = washerCarsServicedMap.get(employee.id) ?? 0;

      const salesRevenueRub =
        employee.role === 'ADMIN'
          ? (adminSalesRevenueRubMap.get(employee.id) ?? 0)
          : 0;

      const bonusRub =
        employee.role === 'ADMIN'
          ? (adminBonusRubMap.get(employee.id) ?? 0)
          : 0;

      const salaryRub =
        employee.role === 'ADMIN'
          ? (adminSalaryRubMap.get(employee.id) ?? 0)
          : 0;

      const earnedRub =
        employee.role === 'ADMIN'
          ? bonusRub + salaryRub
          : (washerEarnedRubMap.get(employee.id) ?? 0);

      return {
        id: employee.id,
        name: employee.name ?? 'Без имени',
        phone: employee.phone,
        role: employee.role,
        isActive: employee.isActive,
        lastLoginAt: employee.lastLoginAt,
        stats: {
          shiftsOpened:
            employee.role === 'WASHER' ? washerShiftsWorked : adminShiftsOpened,
          bookingsHandled,
          discountsGiven,
          suspiciousActions,
          carsServiced,
          salesRevenueRub,
          bonusRub,
          salaryRub,
          earnedRub,
        },
      };
    });

    const admins = analytics.filter((x) => x.role === 'ADMIN');
    const washers = analytics.filter((x) => x.role === 'WASHER');

    return {
      location: {
        id: location.id,
        name: location.name,
      },
      period,
      range: { start, end },
      totals: {
        employees: analytics.length,
        admins: admins.length,
        washers: washers.length,
      },
      admins,
      washers,
      all: analytics,
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

  async getSettings() {
    const location = await this.getLocationForSettings();
    const { contacts, ownerSettings } = await this.readSettingsSnapshot(location);

    return {
      location: {
        id: location.id,
        name: location.name,
        address: location.address,
        colorHex: location.colorHex,
        baysCount: location.baysCount,
      },
      contacts,
      settings: ownerSettings,
      options: {
        suspiciousAuditTypes: this.suspiciousAuditOptions,
      },
    };
  }

  async updateSettings(body: {
    communication?: {
      washStartTemplate?: string;
      washFinishTemplate?: string;
      campaigns?: {
        promotionsEnabled?: boolean;
        discountsEnabled?: boolean;
        holidayGreetingsEnabled?: boolean;
      };
    };
    monitoring?: {
      suspiciousAuditTypes?: string[];
      notifyPhone?: string;
      notifyTelegram?: string;
      notifyPush?: boolean;
    };
  }) {
    const location = await this.getLocationForSettings();
    const { contacts, ownerSettings } = await this.readSettingsSnapshot(location);

    const next: OwnerSettingsConfig = {
      communication: {
        washStartTemplate: ownerSettings.communication.washStartTemplate,
        washFinishTemplate: ownerSettings.communication.washFinishTemplate,
        campaigns: {
          promotionsEnabled:
            ownerSettings.communication.campaigns.promotionsEnabled,
          discountsEnabled:
            ownerSettings.communication.campaigns.discountsEnabled,
          holidayGreetingsEnabled:
            ownerSettings.communication.campaigns.holidayGreetingsEnabled,
        },
      },
      monitoring: {
        suspiciousAuditTypes: [...ownerSettings.monitoring.suspiciousAuditTypes],
        notifyPhone: ownerSettings.monitoring.notifyPhone,
        notifyTelegram: ownerSettings.monitoring.notifyTelegram,
        notifyPush: ownerSettings.monitoring.notifyPush,
      },
    };

    if (body.communication) {
      if (typeof body.communication.washStartTemplate === 'string') {
        next.communication.washStartTemplate = this.normalizeOptionalText(
          body.communication.washStartTemplate,
          1000,
        );
      }

      if (typeof body.communication.washFinishTemplate === 'string') {
        next.communication.washFinishTemplate = this.normalizeOptionalText(
          body.communication.washFinishTemplate,
          1000,
        );
      }

      if (body.communication.campaigns) {
        if (
          typeof body.communication.campaigns.promotionsEnabled === 'boolean'
        ) {
          next.communication.campaigns.promotionsEnabled =
            body.communication.campaigns.promotionsEnabled;
        }

        if (
          typeof body.communication.campaigns.discountsEnabled === 'boolean'
        ) {
          next.communication.campaigns.discountsEnabled =
            body.communication.campaigns.discountsEnabled;
        }

        if (
          typeof body.communication.campaigns.holidayGreetingsEnabled ===
          'boolean'
        ) {
          next.communication.campaigns.holidayGreetingsEnabled =
            body.communication.campaigns.holidayGreetingsEnabled;
        }
      }
    }

    if (body.monitoring) {
      if (Array.isArray(body.monitoring.suspiciousAuditTypes)) {
        const normalized = this.normalizeSuspiciousAuditTypes(
          body.monitoring.suspiciousAuditTypes,
        );

        next.monitoring.suspiciousAuditTypes =
          normalized.length > 0 ? normalized : [...this.suspiciousAuditTypes];
      }

      if (typeof body.monitoring.notifyPhone === 'string') {
        next.monitoring.notifyPhone = this.normalizeOptionalPhone(
          body.monitoring.notifyPhone,
        );
      }

      if (typeof body.monitoring.notifyTelegram === 'string') {
        next.monitoring.notifyTelegram = this.normalizeTelegramHandle(
          body.monitoring.notifyTelegram,
        );
      }

      if (typeof body.monitoring.notifyPush === 'boolean') {
        next.monitoring.notifyPush = body.monitoring.notifyPush;
      }
    }

    const normalizedFinal = this.normalizeOwnerSettings(
      next,
      this.getDefaultOwnerSettings(contacts),
    );

    await this.prisma.tenantFeature.upsert({
      where: {
        tenantId_key: {
          tenantId: location.tenantId,
          key: 'OWNER_SETTINGS',
        },
      },
      update: {
        enabled: true,
        params: normalizedFinal as any,
      },
      create: {
        tenantId: location.tenantId,
        key: 'OWNER_SETTINGS',
        enabled: true,
        params: normalizedFinal as any,
      },
      select: { id: true },
    });

    return this.getSettings();
  }

  async getCompensationSettings() {
    const location = await this.getLocation();
    const defaults = this.getDefaultCompensationSettings();

    const settings = await this.prisma.locationCompensationSettings.findUnique({
      where: { locationId: location.id },
      select: {
        washerBasePercent: true,
        washerAddonPercent: true,
        adminBaseSalaryRub: true,
        adminBasePercent: true,
        adminAddonPercent: true,
        adminUpsellPercent: true,
        isActive: true,
        updatedAt: true,
      },
    });

    return {
      location: {
        id: location.id,
        name: location.name,
      },
      compensation: {
        washerBasePercent:
          settings?.washerBasePercent ?? defaults.washerBasePercent,
        washerAddonPercent:
          settings?.washerAddonPercent ?? defaults.washerAddonPercent,
        adminBaseSalaryRub:
          settings?.adminBaseSalaryRub ?? defaults.adminBaseSalaryRub,
        adminBasePercent:
          settings?.adminBasePercent ?? defaults.adminBasePercent,
        adminAddonPercent:
          settings?.adminAddonPercent ?? defaults.adminAddonPercent,
        adminUpsellPercent:
          settings?.adminUpsellPercent ?? defaults.adminUpsellPercent,
        isActive: settings?.isActive ?? true,
        updatedAt: settings?.updatedAt ?? null,
      },
    };
  }

  async updateCompensationSettings(body: {
    washerBasePercent?: number;
    washerAddonPercent?: number;
    adminBaseSalaryRub?: number;
    adminBasePercent?: number;
    adminAddonPercent?: number;
    adminUpsellPercent?: number;
  }) {
    const location = await this.getLocation();
    const current = await this.getCompensationSettings();

    const currentComp = current.compensation;

    const next = {
      washerBasePercent:
        body.washerBasePercent !== undefined
          ? this.normalizePercent(body.washerBasePercent, 'washerBasePercent')
          : currentComp.washerBasePercent,
      washerAddonPercent:
        body.washerAddonPercent !== undefined
          ? this.normalizePercent(body.washerAddonPercent, 'washerAddonPercent')
          : currentComp.washerAddonPercent,
      adminBaseSalaryRub:
        body.adminBaseSalaryRub !== undefined
          ? this.normalizeMoneyRub(
              body.adminBaseSalaryRub,
              'adminBaseSalaryRub',
            )
          : currentComp.adminBaseSalaryRub,
      adminBasePercent:
        body.adminBasePercent !== undefined
          ? this.normalizePercent(body.adminBasePercent, 'adminBasePercent')
          : currentComp.adminBasePercent,
      adminAddonPercent:
        body.adminAddonPercent !== undefined
          ? this.normalizePercent(body.adminAddonPercent, 'adminAddonPercent')
          : currentComp.adminAddonPercent,
      adminUpsellPercent:
        body.adminUpsellPercent !== undefined
          ? this.normalizePercent(
              body.adminUpsellPercent,
              'adminUpsellPercent',
            )
          : currentComp.adminUpsellPercent,
    };

    await this.prisma.locationCompensationSettings.upsert({
      where: { locationId: location.id },
      update: {
        washerBasePercent: next.washerBasePercent,
        washerAddonPercent: next.washerAddonPercent,
        adminBaseSalaryRub: next.adminBaseSalaryRub,
        adminBasePercent: next.adminBasePercent,
        adminAddonPercent: next.adminAddonPercent,
        adminUpsellPercent: next.adminUpsellPercent,
        isActive: true,
      },
      create: {
        locationId: location.id,
        washerBasePercent: next.washerBasePercent,
        washerAddonPercent: next.washerAddonPercent,
        adminBaseSalaryRub: next.adminBaseSalaryRub,
        adminBasePercent: next.adminBasePercent,
        adminAddonPercent: next.adminAddonPercent,
        adminUpsellPercent: next.adminUpsellPercent,
        isActive: true,
      },
    });

    return this.getCompensationSettings();
  }

  async changeOwnerPassword(body: { password?: string }) {
    const location = await this.getLocation();
    const owner = await this.getOwnerUserOrThrow(location.id);

    const password = this.validatePassword(body.password);
    const passwordHash = await this.hashPassword(password);

    await this.prisma.user.update({
      where: { id: owner.id },
      data: {
        passwordHash,
        mustChangePassword: false,
      },
    });

    return {
      ok: true,
      owner: {
        id: owner.id,
        name: owner.name,
        phone: owner.phone,
      },
    };
  }
}