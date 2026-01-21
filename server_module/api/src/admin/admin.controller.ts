import { Body, Controller, Get, Headers, Post, Query } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminLoginDto } from './dto/admin-login.dto';

@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // POST /admin/login
  @Post('login')
  login(@Body() dto: AdminLoginDto) {
    return this.admin.login(dto.phone);
  }

  // GET /admin/me  (x-user-id)
  @Get('me')
  me(@Headers('x-user-id') userId?: string) {
    return this.admin.me((userId ?? '').trim());
  }

  // GET /admin/calendar/day?locationId=...&date=YYYY-MM-DD  (x-user-id)
  @Get('calendar/day')
  calendarDay(
    @Headers('x-user-id') userId?: string,
    @Query('locationId') locationId?: string,
    @Query('date') date?: string,
  ) {
    return this.admin.calendarDay(
      (userId ?? '').trim(),
      (locationId ?? '').trim(),
      (date ?? '').trim(),
    );
  }
}
