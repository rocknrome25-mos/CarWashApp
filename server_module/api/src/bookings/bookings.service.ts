import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus } from '@prisma/client';

@Injectable()
export class BookingsService {
  constructor(private prisma: PrismaService) {}

  async findAll(includeCanceled: boolean) {
    return this.prisma.booking.findMany({
      where: includeCanceled ? {} : { status: BookingStatus.ACTIVE },
      orderBy: { dateTime: 'asc' },
      include: { car: true, service: true },
    });
  }

  async create(body: {
    carId: string;
    serviceId: string;
    dateTime: string;
  }) {
    const dt = new Date(body.dateTime);
    if (isNaN(dt.getTime())) {
      throw new BadRequestException('dateTime must be ISO string');
    }

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

    if (existing.status === BookingStatus.CANCELED) {
      return existing;
    }

    return this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.CANCELED,
      },
    });
  }
}
