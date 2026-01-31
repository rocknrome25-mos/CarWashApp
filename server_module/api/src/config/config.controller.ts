import { BadRequestException, Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ConfigService } from './config.service';

@Controller('config')
export class ConfigController {
  constructor(private readonly cfg: ConfigService) {}

  // GET /config?locationId=...
  @Get()
  async getConfig(@Query('locationId') locationId?: string) {
    const loc = (locationId ?? '').trim();
    if (!loc) throw new BadRequestException('locationId is required');
    return this.cfg.getConfigByLocationId(loc);
  }

  // ✅ OWNER/ADMIN settings (temporarily open; позже закроем авторизацией)
  // POST /config/contacts?locationId=...
  @Post('contacts')
  async upsertContacts(
    @Query('locationId') locationId?: string,
    @Body() body: any = {},
  ) {
    const loc = (locationId ?? '').trim();
    if (!loc) throw new BadRequestException('locationId is required');

    return this.cfg.upsertContactsByLocationId(loc, body);
  }
}
