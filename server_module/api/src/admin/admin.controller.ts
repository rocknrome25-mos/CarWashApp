import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminLoginDto } from './dto/admin-login.dto';
import { AdminBookingStartDto } from './dto/admin-booking-start.dto';
import { AdminBookingFinishDto } from './dto/admin-booking-finish.dto';
import { AdminBookingMoveDto } from './dto/admin-booking-move.dto';

@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // POST /admin/login { phone }
  @Post('login')
  login(@Body() dto: AdminLoginDto) {
    return this.admin.login(dto);
  }

  // POST /admin/shifts/open  (headers: x-user-id)
  @Post('shifts/open')
  openShift(@Headers('x-user-id') userId?: string) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.admin.openShift(uid);
  }

  // POST /admin/shifts/close (headers: x-user-id, x-shift-id)
  @Post('shifts/close')
  closeShift(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.closeShift(uid, sid);
  }

  // GET /admin/calendar/day?date=YYYY-MM-DD (headers: x-user-id, x-shift-id)
  @Get('calendar/day')
  calendarDay(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Query('date') date?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const d = (date ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!d) throw new BadRequestException('date is required (YYYY-MM-DD)');
    return this.admin.getCalendarDay(uid, sid, d);
  }

  // POST /admin/bookings/:id/start
  @Post('bookings/:id/start')
  startBooking(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() dto: AdminBookingStartDto = {} as AdminBookingStartDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.startBooking(uid, sid, bid, dto);
  }

  // POST /admin/bookings/:id/finish
  @Post('bookings/:id/finish')
  finishBooking(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() dto: AdminBookingFinishDto = {} as AdminBookingFinishDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.finishBooking(uid, sid, bid, dto);
  }

  // POST /admin/bookings/:id/move
  @Post('bookings/:id/move')
  moveBooking(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() dto: AdminBookingMoveDto = {} as AdminBookingMoveDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.moveBooking(uid, sid, bid, dto);
  }
}
