import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Post,
  Query,
} from '@nestjs/common';
import { WasherService } from './washer.service';
import { WasherLoginDto } from './dto/washer-login.dto';
import { WasherClockDto } from './dto/washer-clock.dto';

@Controller('washer')
export class WasherController {
  constructor(private readonly washer: WasherService) {}

  @Post('login')
  login(@Body() dto: WasherLoginDto) {
    return this.washer.login(dto);
  }

  @Get('shift/current')
  getCurrentShift(@Headers('x-user-id') userId?: string) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.washer.getCurrentShift(uid);
  }

  @Get('shift/current/bookings')
  getCurrentShiftBookings(@Headers('x-user-id') userId?: string) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.washer.getCurrentShiftBookings(uid);
  }

  @Post('clock-in')
  clockIn(
    @Headers('x-user-id') userId?: string,
    @Body() dto: WasherClockDto = {} as WasherClockDto,
  ) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.washer.clockIn(uid, dto);
  }

  @Post('clock-out')
  clockOut(
    @Headers('x-user-id') userId?: string,
    @Body() dto: WasherClockDto = {} as WasherClockDto,
  ) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.washer.clockOut(uid, dto);
  }

  @Get('stats')
  stats(
    @Headers('x-user-id') userId?: string,
    @Query('from') fromRaw?: string,
    @Query('to') toRaw?: string,
  ) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');

    const fromS = (fromRaw ?? '').trim();
    const toS = (toRaw ?? '').trim();
    if (!fromS || !toS) throw new BadRequestException('from and to are required');

    return this.washer.getStats(uid, fromS, toS);
  }

  // ✅ NEW: washer schedule
  @Get('schedule')
  schedule(
    @Headers('x-user-id') userId?: string,
    @Query('from') fromRaw?: string,
    @Query('to') toRaw?: string,
  ) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');

    const fromS = (fromRaw ?? '').trim();
    const toS = (toRaw ?? '').trim();
    if (!fromS || !toS) throw new BadRequestException('from and to are required');

    return this.washer.getSchedule(uid, fromS, toS);
  }
}
