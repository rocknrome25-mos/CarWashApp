import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UserRole } from '@prisma/client';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  private _normalizePhone(phone: string) {
    return phone.trim();
  }

  async login(phoneRaw: string) {
    const phone = this._normalizePhone(phoneRaw);
    if (!phone) throw new BadRequestException('phone is required');

    const user = await this.prisma.user.findUnique({
      where: { phone },
      include: { location: true },
    });

    if (!user) throw new ForbiddenException('User not found');
    if (!user.isActive) throw new ForbiddenException('User is inactive');
    if (user.role !== UserRole.ADMIN && user.role !== UserRole.OWNER) {
      throw new ForbiddenException('Forbidden');
    }

    // временно возвращаем userId, потом заменим на JWT
    return {
      userId: user.id,
      role: user.role,
      locationId: user.locationId,
      location: {
        id: user.location.id,
        name: user.location.name,
        address: user.location.address,
        colorHex: user.location.colorHex,
        baysCount: user.location.baysCount,
      },
    };
  }

  async me(userId: string) {
    if (!userId?.trim()) throw new BadRequestException('x-user-id is required');

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { location: true },
    });

    if (!user) throw new ForbiddenException('User not found');
    if (!user.isActive) throw new ForbiddenException('User is inactive');
    if (user.role !== UserRole.ADMIN && user.role !== UserRole.OWNER) {
      throw new ForbiddenException('Forbidden');
    }

    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      role: user.role,
      locationId: user.locationId,
      location: user.location
        ? {
            id: user.location.id,
            name: user.location.name,
            address: user.location.address,
            colorHex: user.location.colorHex,
            baysCount: user.location.baysCount,
          }
        : null,
    };
  }

  async calendarDay(userId: string, locationId: string, dateYmd: string) {
    const me = await this.me(userId);

    // rule: admin scope = location only (позже добавим shift rule)
    if (me.role === UserRole.ADMIN && me.locationId !== locationId) {
      throw new ForbiddenException('No access to this location');
    }

    // dateYmd: "YYYY-MM-DD"
    const [y, m, d] = dateYmd.split('-').map((x) => Number(x));
    if (!y || !m || !d) throw new BadRequestException('date must be YYYY-MM-DD');

    const from = new Date(Date.UTC(y, m - 1, d, 0, 0, 0));
    const to = new Date(Date.UTC(y, m - 1, d + 1, 0, 0, 0));

    // ВАЖНО: dateTime у тебя хранится как DateTime (обычно UTC).
    // Мы будем отдавать список бронирований на день, а UI сам разложит по слотам.
    const bookings = await this.prisma.booking.findMany({
      where: {
        locationId,
        dateTime: { gte: from, lt: to },
      },
      orderBy: [{ bayId: 'asc' }, { dateTime: 'asc' }],
      include: {
        car: true,
        service: true,
        payments: { orderBy: { paidAt: 'asc' } },
        client: { select: { id: true, phone: true, name: true } }, // админ видит контакт
      },
    });

    // базовая сводка для UI
    const total = bookings.length;
    const byBay: Record<string, number> = {};
    for (const b of bookings) {
      const k = String(b.bayId ?? 1);
      byBay[k] = (byBay[k] ?? 0) + 1;
    }

    return {
      locationId,
      date: dateYmd,
      total,
      byBay,
      bookings,
    };
  }
}
