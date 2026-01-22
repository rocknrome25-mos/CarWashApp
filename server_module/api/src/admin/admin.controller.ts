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

import { OpenFloatDto } from './cash/dto/open-float.dto';
import { CashMoveDto } from './cash/dto/cash-move.dto';
import { CloseCashDto } from './cash/dto/close-cash.dto';

import { AdminBookingPayDto } from './dto/admin-booking-pay.dto';

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

  // ===== CASH =====

  @Post('cash/open-float')
  openFloat(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Body() dto: OpenFloatDto = {} as OpenFloatDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.cashOpenFloat(uid, sid, dto);
  }

  @Post('cash/in')
  cashIn(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Body() dto: CashMoveDto = {} as CashMoveDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.cashIn(uid, sid, dto);
  }

  @Post('cash/out')
  cashOut(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Body() dto: CashMoveDto = {} as CashMoveDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.cashOut(uid, sid, dto);
  }

  @Post('cash/close')
  closeCash(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Body() dto: CloseCashDto = {} as CloseCashDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.cashClose(uid, sid, dto);
  }

  @Get('cash/summary')
  cashSummary(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.cashSummary(uid, sid);
  }

  @Get('cash/expected')
  cashExpected(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.cashExpected(uid, sid);
  }

  // ===== CALENDAR =====

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

  // ===== BOOKINGS =====

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

  // ✅ NEW: admin payment marking
  @Post('bookings/:id/pay')
  payBooking(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() dto: AdminBookingPayDto = {} as AdminBookingPayDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.payBookingAdmin(uid, sid, bid, dto);
  }
}
