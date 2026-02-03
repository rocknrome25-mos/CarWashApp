import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Query,
  Delete,
  UploadedFile,
  UseInterceptors,
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
import { AdminBookingDiscountDto } from './dto/admin-booking-discount.dto';

import { AdminBayCloseDto } from './dto/admin-bay-close.dto';
import { AdminBayOpenDto } from './dto/admin-bay-open.dto';

import { FileInterceptor } from '@nestjs/platform-express';
import multer from 'multer';

@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Post('login')
  login(@Body() dto: AdminLoginDto) {
    return this.admin.login(dto);
  }

  @Post('shifts/open')
  openShift(@Headers('x-user-id') userId?: string) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.admin.openShift(uid);
  }

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

  // ===== BAY (close/open) =====

  @Get('bays')
  listBays(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    return this.admin.listBays(uid, sid);
  }

  @Post('bays/:number/close')
  closeBay(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('number') numberRaw?: string,
    @Body() dto: AdminBayCloseDto = {} as AdminBayCloseDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const n = Number(numberRaw);
    const bayNumber = Number.isFinite(n) ? Math.trunc(n) : 0;
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (bayNumber < 1 || bayNumber > 20) {
      throw new BadRequestException('bay number must be 1..20');
    }
    return this.admin.closeBay(uid, sid, bayNumber, dto);
  }

  @Post('bays/:number/open')
  openBay(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('number') numberRaw?: string,
    @Body() dto: AdminBayOpenDto = {} as AdminBayOpenDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const n = Number(numberRaw);
    const bayNumber = Number.isFinite(n) ? Math.trunc(n) : 0;
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (bayNumber < 1 || bayNumber > 20) {
      throw new BadRequestException('bay number must be 1..20');
    }
    return this.admin.openBay(uid, sid, bayNumber, dto);
  }

  // ===== WAITLIST =====

  @Get('waitlist/day')
  waitlistDay(
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
    return this.admin.getWaitlistDay(uid, sid, d);
  }

  @Post('waitlist/:id/convert')
  convertWaitlist(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') waitlistId?: string,
    @Body() body: any = {},
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const wid = (waitlistId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!wid) throw new BadRequestException('waitlist id is required');

    const bayId = body?.bayId;
    const dateTime = body?.dateTime;
    return this.admin.convertWaitlistToBooking(uid, sid, wid, {
      bayId,
      dateTime,
    });
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

  @Post('bookings/:id/discount')
  discountBooking(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() dto: AdminBookingDiscountDto = {} as AdminBookingDiscountDto,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.applyDiscount(uid, sid, bid, dto);
  }

  // ===== UPSALE (addons) =====

  @Get('bookings/:id/addons')
  listAddons(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.listBookingAddons(uid, sid, bid);
  }

  @Post('bookings/:id/addons')
  addAddon(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() body: any = {},
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    const serviceId = (body?.serviceId ?? '').toString().trim();
    const qty = body?.qty;
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    if (!serviceId) throw new BadRequestException('serviceId is required');
    return this.admin.addBookingAddon(uid, sid, bid, { serviceId, qty });
  }

  @Delete('bookings/:id/addons/:serviceId')
  removeAddon(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Param('serviceId') serviceId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    const sid2 = (serviceId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    if (!sid2) throw new BadRequestException('serviceId is required');
    return this.admin.removeBookingAddon(uid, sid, bid, sid2);
  }

  // ===== PHOTOS =====

  @Get('bookings/:id/photos')
  listPhotos(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    return this.admin.listBookingPhotos(uid, sid, bid);
  }

  @Post('bookings/:id/photos')
  addPhoto(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @Body() body: any = {},
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    const kind = (body?.kind ?? '').toString().trim();
    const url = (body?.url ?? '').toString().trim();
    const note = (body?.note ?? '').toString().trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    if (!kind) throw new BadRequestException('kind is required (BEFORE/AFTER)');
    if (!url) throw new BadRequestException('url is required');
    return this.admin.addBookingPhoto(uid, sid, bid, { kind, url, note });
  }

  // ✅ NEW: upload file (multipart/form-data) -> /admin/bookings/:id/photos/upload
  @Post('bookings/:id/photos/upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: multer.memoryStorage(),
      limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    }),
  )
  uploadPhoto(
    @Headers('x-user-id') userId?: string,
    @Headers('x-shift-id') shiftId?: string,
    @Param('id') bookingId?: string,
    @UploadedFile() file?: Express.Multer.File,
    @Body() body: any = {},
  ) {
    const uid = (userId ?? '').trim();
    const sid = (shiftId ?? '').trim();
    const bid = (bookingId ?? '').trim();
    const kind = (body?.kind ?? '').toString().trim();
    const note = (body?.note ?? '').toString().trim();

    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!sid) throw new BadRequestException('x-shift-id is required');
    if (!bid) throw new BadRequestException('booking id is required');
    if (!kind) throw new BadRequestException('kind is required (BEFORE/AFTER/DAMAGE/OTHER)');
    if (!file) throw new BadRequestException('file is required');

    return this.admin.uploadBookingPhoto(uid, sid, bid, { kind, note, file });
  }
}
