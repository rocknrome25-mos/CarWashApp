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

  // Variant B: persist auto-complete past ACTIVE bookings
  private async _autoCompletePastActive(): Promise<void> {
    const now = new Date();
    await this.prisma.booking.updateMany({
      where: {
        status: BookingStatus.ACTIVE,
        dateTime: { lt: now },
      },
      data: { status: BookingStatus.COMPLETED },
    });
  }

  async findAll(includeCanceled: boolean) {
    await this._autoCompletePastActive();

    // show:
    // - includeCanceled=true => ACTIVE + CANCELED + COMPLETED
    // - includeCanceled=false => ACTIVE + COMPLETED (hide only canceled)
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
    await this._autoCompletePastActive();

    if (!body || !body.carId || !body.serviceId || !body.dateTime) {
      throw new BadRequestException('carId, serviceId and dateTime are required');
    }

    const dt = new Date(body.dateTime);
    if (isNaN(dt.getTime())) {
      throw new BadRequestException('dateTime must be ISO string');
    }

    const now = Date.now();
    const graceMs = 30 * 1000;
    if (dt.getTime() < now - graceMs) {
      throw new BadRequestException('Cannot create booking in the past');
    }

    const car = await this.prisma.car.findUnique({ where: { id: body.carId } });
    if (!car) throw new BadRequestException('Car not found');

    const service = await this.prisma.service.findUnique({
      where: { id: body.serviceId },
    });
    if (!service) throw new BadRequestException('Service not found');

    // slot busy? (same dateTime for any ACTIVE booking)
    const slotBusy = await this.prisma.booking.findFirst({
      where: { dateTime: dt, status: BookingStatus.ACTIVE },
      select: { id: true },
    });
    if (slotBusy) throw new ConflictException('Selected time slot is already booked');

    // same car already booked at same time?
    const carBusy = await this.prisma.booking.findFirst({
      where: { carId: body.carId, dateTime: dt, status: BookingStatus.ACTIVE },
      select: { id: true },
    });
    if (carBusy) throw new ConflictException('This car already has a booking at this time');

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
    await this._autoCompletePastActive();

    const existing = await this.prisma.booking.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Booking not found');

    if (existing.status === BookingStatus.CANCELED) return existing;

    // if already completed, no cancel
    if (existing.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }

    // can't cancel past bookings
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
