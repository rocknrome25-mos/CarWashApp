import {
  Body,
  Controller,
  Post,
  BadRequestException,
  Headers,
} from '@nestjs/common';
import { AdminBookingsService } from './admin_bookings.service';

@Controller('admin/bookings')
export class AdminBookingsController {
  constructor(private readonly svc: AdminBookingsService) {}

  @Post('manual')
  async createManual(
    @Body() body: any,
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
  ) {
    const locationId = (body?.locationId ?? '').toString().trim();
    const dateTime = (body?.dateTime ?? '').toString().trim();
    const serviceId = (body?.serviceId ?? '').toString().trim();

    if (!locationId) throw new BadRequestException('locationId is required');
    if (!dateTime) throw new BadRequestException('dateTime is required');
    if (!serviceId) throw new BadRequestException('serviceId is required');

    const uid = (userId ?? '').toString().trim() || null;
    const sid = (shiftId ?? '').toString().trim() || null;

    return this.svc.createManual(body, { userId: uid, shiftId: sid });
  }
}
