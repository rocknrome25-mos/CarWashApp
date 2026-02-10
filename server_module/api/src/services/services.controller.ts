import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ServicesService } from './services.service';

@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  // GET /services?locationId=...&kind=BASE|ADDON&includeInactive=true
  @Get()
  getAll(
    @Query('locationId') locationId?: string,
    @Query('kind') kind?: 'BASE' | 'ADDON',
    @Query('includeInactive') includeInactive?: string,
  ) {
    const loc = (locationId ?? '').trim();
    if (!loc) {
      throw new BadRequestException('locationId is required');
    }

    const inc = (includeInactive ?? '').toString().toLowerCase();
    const include = inc === 'true' || inc === '1' || inc === 'yes';

    const k = (kind ?? '').trim().toUpperCase();
    const kindNorm = k === 'BASE' || k === 'ADDON' ? (k as 'BASE' | 'ADDON') : undefined;

    return this.servicesService.findAll({
      locationId: loc,
      kind: kindNorm,
      includeInactive: include,
    });
  }
}
