import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
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
}
