import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus } from '@prisma/client';

@Injectable()
export class BookingsService {
  constructor(private prisma: PrismaService) {}

  // Variant A: auto-complete past ACTIVE bookings
  private async _autoCompletePastActive(): Promise<void> {
    const now = new Date();
    await this.prisma.booking.updateMany({
      where: {
        status: BookingStatus.ACTIVE,
        dateTime: { lt: now },
      },
      data: {
        status: BookingStatus.COMPLETED,
      },
    });
  }

  async findAll(includeCanceled: boolean) {
    // ✅ make sure old ACTIVE become COMPLETED
    await this._autoCompletePastActive();

    // show:
    // - if includeCanceled = true: ACTIVE + CANCELED + COMPLETED
    // - else: ACTIVE + COMPLETED (hide only canceled)
    const where = includeCanceled
      ? {}
      : { status: { not: BookingStatus.CANCELED } };

    return this.prisma.booking.findMany({
      where,
      orderBy: { dateTime: 'asc' },
      include: { car: true, service: true },
    });
  }

  async create(body: { carId: string; serviceId: string; dateTime: string }) {
    if (!body || !body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException('carId, serviceId and dateTime are required');
    }

    // 1) validate date
    const dt = new Date(body.dateTime);
    if (isNaN(dt.getTime())) {
      throw new BadRequestException('dateTime must be ISO string');
    }

    // 2) no past bookings (small grace period to avoid edge cases)
    const now = Date.now();
    const graceMs = 30 * 1000; // 30 sec
    if (dt.getTime() < now - graceMs) {
      throw new BadRequestException('Cannot create booking in the past');
    }

    // 3) ensure car exists (optional but better errors)
    const car = await this.prisma.car.findUnique({ where: { id: body.carId } });
    if (!car) {
      throw new BadRequestException('Car not found');
    }

    // 4) ensure service exists
    const service = await this.prisma.service.findUnique({
      where: { id: body.serviceId },
    });
    if (!service) {
      throw new BadRequestException('Service not found');
    }

    // 5) slot busy? (same dateTime for any ACTIVE booking)
    const slotBusy = await this.prisma.booking.findFirst({
      where: {
        dateTime: dt,
        status: BookingStatus.ACTIVE,
      },
      select: { id: true },
    });
    if (slotBusy) {
      throw new ConflictException('Selected time slot is already booked');
    }

    // 6) same car already booked at same time?
    const carBusy = await this.prisma.booking.findFirst({
      where: {
        carId: body.carId,
        dateTime: dt,
        status: BookingStatus.ACTIVE,
      },
      select: { id: true },
    });
    if (carBusy) {
      throw new ConflictException('This car already has a booking at this time');
    }

    // 7) create
    return this.prisma.booking.create({
      data: {
        carId: body.carId,
        serviceId: body.serviceId,
        dateTime: dt,
        status: BookingStatus.ACTIVE,
      },
      include: { car: true, service: true },
    });
  }

  async cancel(id: string) {
    const existing = await this.prisma.booking.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException('Booking not found');
    }

    // idempotent
    if (existing.status === BookingStatus.CANCELED) {
      return existing;
    }

    // can't cancel past bookings (Variant A: past should become COMPLETED anyway)
    if (existing.dateTime.getTime() < Date.now()) {
      throw new BadRequestException('Cannot cancel a past booking');
    }

    return this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.CANCELED,
        canceledAt: new Date(),
      },
    });
  }
}
