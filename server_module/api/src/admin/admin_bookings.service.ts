import {
  Injectable,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

function normPlate(s: string): string {
  return (s ?? '')
    .toUpperCase()
    .replace(/\s+/g, '')
    .replace(/[^A-Z0-9А-Я]/g, '');
}

function roundUpToStep(mins: number, step: number) {
  const q = Math.ceil(mins / step);
  return Math.max(step, q * step);
}

@Injectable()
export class AdminBookingsService {
  constructor(private prisma: PrismaService) {}

  async createManual(
    payload: any,
    ctx: { userId: string | null; shiftId: string | null },
  ) {
    const locationId = (payload?.locationId ?? '').toString().trim();
    const bayId = Number(payload?.bayId ?? 1);

    const dtRaw = (payload?.dateTime ?? '').toString();
    const start = new Date(dtRaw);

    if (!locationId) throw new BadRequestException('locationId is required');
    if (!Number.isFinite(bayId) || bayId < 1) {
      throw new BadRequestException('bayId is invalid');
    }
    if (Number.isNaN(start.getTime())) {
      throw new BadRequestException('dateTime is invalid');
    }

    const serviceId = (payload?.serviceId ?? '').toString().trim();
    if (!serviceId) throw new BadRequestException('serviceId is required');

    // 0) check bay state (if closed => WAITLIST)
    const bayRow = await this.prisma.bay.findFirst({
      where: { locationId, number: bayId },
      select: { isActive: true, closedReason: true },
    });

    // if bay row missing -> treat as closed
    const bayIsOpen = bayRow?.isActive === true;

    // if all bays closed -> WAITLIST too
    const anyOpenBay = await this.prisma.bay.findFirst({
      where: { locationId, isActive: true },
      select: { number: true },
    });
    const allBaysClosed = !anyOpenBay;

    // --- base service ---
    const baseService = await this.prisma.service.findFirst({
      where: { id: serviceId, locationId, isActive: true },
    });
    if (!baseService) throw new BadRequestException('base service not found');

    // --- addons (optional) ---
    const addonsIn = Array.isArray(payload?.addons) ? payload.addons : [];
    const addonIds = addonsIn
      .map((a: any) => (a?.serviceId ?? '').toString().trim())
      .filter((x: string) => x.length > 0);

    const addonServices = addonIds.length
      ? await this.prisma.service.findMany({
          where: { id: { in: addonIds }, locationId, isActive: true },
        })
      : [];

    // duration model (UI should match)
    const bufferMin = 15;
    const addonMin = addonServices.reduce(
      (sum, s) => sum + (s.durationMin ?? 0),
      0,
    );
    const blockMin = roundUpToStep(
      (baseService.durationMin ?? 30) + addonMin + bufferMin,
      30,
    );
    const end = new Date(start.getTime() + blockMin * 60_000);

    // --- client upsert by phone (optional) ---
    const clientPhone = (payload?.client?.phone ?? '').toString().trim();
    const clientName = (payload?.client?.name ?? '').toString().trim();
    let clientId: string | null = null;

    if (clientPhone) {
      const existingClient = await this.prisma.client.findUnique({
        where: { phone: clientPhone },
      });

      if (existingClient) {
        clientId = existingClient.id;
        if (clientName && (existingClient.name ?? '').trim() !== clientName) {
          await this.prisma.client.update({
            where: { id: existingClient.id },
            data: { name: clientName },
          });
        }
      } else {
        const created = await this.prisma.client.create({
          data: { phone: clientPhone, name: clientName || null },
        });
        clientId = created.id;
      }
    }

    // --- car upsert by plateNormalized ---
    const plateDisplay = (payload?.car?.plate ?? '').toString().trim();
    const plateNorm = normPlate(plateDisplay);
    if (!plateNorm) throw new BadRequestException('car plate is required');

    const bodyType = payload?.car?.bodyType
      ? String(payload.car.bodyType)
      : null;

    let carId: string;
    const existingCar = await this.prisma.car.findUnique({
      where: { plateNormalized: plateNorm },
    });

    if (existingCar) {
      carId = existingCar.id;
      if (clientId && !existingCar.clientId) {
        await this.prisma.car.update({
          where: { id: existingCar.id },
          data: { clientId },
        });
      }
    } else {
      const createdCar = await this.prisma.car.create({
        data: {
          makeDisplay: '—',
          modelDisplay: '—',
          plateDisplay: plateDisplay || plateNorm,
          makeNormalized: '—',
          modelNormalized: '—',
          plateNormalized: plateNorm,
          bodyType,
          clientId: clientId ?? null,
        },
      });
      carId = createdCar.id;
    }

    // 1) if bay closed OR all bays closed => WAITLIST
    if (!bayIsOpen || allBaysClosed) {
      const reason = allBaysClosed
        ? 'ALL_BAYS_CLOSED_ADMIN'
        : `BAY_CLOSED_ADMIN:${bayId}:${(bayRow?.closedReason ?? '').toString()}`;

      const desiredBayId = bayId; // what admin requested

      const wait = await this.prisma.waitlistRequest.create({
        data: {
          status: 'WAITING',
          locationId,
          desiredDateTime: start,
          desiredBayId,
          clientId: clientId!, // admin создаёт “по звонку” => телефон обязателен в UI
          carId,
          serviceId: baseService.id,
          comment: null,
          reason,
        },
        include: {
          service: true,
          client: true,
          car: true,
        },
      });

      return { resultType: 'WAITLIST', waitlist: wait };
    }

    // 2) Otherwise — create Booking (with conflict check)
    const existing = await this.prisma.booking.findMany({
      where: {
        locationId,
        bayId,
        status: { in: ['ACTIVE', 'PENDING_PAYMENT'] },
        dateTime: {
          gte: new Date(start.getTime() - 24 * 60 * 60_000),
          lte: new Date(end.getTime() + 24 * 60 * 60_000),
        },
      },
      include: { service: true, addons: true },
    });

    for (const b of existing) {
      const bBase = b.service?.durationMin ?? 30;
      const bAddon = (b.addons ?? []).reduce(
        (sum, a) => sum + (a.durationMinSnapshot ?? 0) * (a.qty ?? 1),
        0,
      );
      const bBlock = roundUpToStep(
        bBase + bAddon + (b.bufferMin ?? 0),
        30,
      );
      const bStart = new Date(b.dateTime);
      const bEnd = new Date(bStart.getTime() + bBlock * 60_000);
      if (bStart < end && start < bEnd) {
        throw new ConflictException('slot occupied');
      }
    }

    // --- create booking + addons ---
    const booking = await this.prisma.$transaction(async (tx) => {
      const b = await tx.booking.create({
        data: {
          locationId,
          shiftId: ctx.shiftId ?? null, // ✅ keep shiftId so it shows in Shift screen
          dateTime: start,
          bayId,
          requestedBayId: null,
          bufferMin,
          depositRub: 0,
          comment: null,
          adminNote: 'Создано админом',
          status: 'ACTIVE',
          paymentDueAt: null,
          carId,
          serviceId: baseService.id,
          clientId,
        },
        include: {
          service: true,
          client: true,
          car: true,
        },
      });

      for (const s of addonServices) {
        await tx.bookingAddon.create({
          data: {
            bookingId: b.id,
            serviceId: s.id,
            qty: 1,
            priceRubSnapshot: s.priceRub,
            durationMinSnapshot: s.durationMin ?? 0,
          },
        });
      }

      return b;
    });

    return { resultType: 'BOOKING', booking };
  }
}
