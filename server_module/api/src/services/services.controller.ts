import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ServiceKind } from '@prisma/client';
import { ServicesService } from './services.service';

@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  // GET /services?locationId=...&kind=BASE|ADDON&includeInactive=true
  @Get()
  getAll(
    @Query('locationId') locationId?: string,
    @Query('kind') kind?: string,
    @Query('includeInactive') includeInactive?: string,
  ) {
    const loc = (locationId ?? '').trim();
    if (!loc) {
      throw new BadRequestException('locationId is required');
    }

    const include = this.parseBoolean(includeInactive);

    const kindRaw = (kind ?? '').trim().toUpperCase();
    let kindNorm: ServiceKind | undefined;

    if (kindRaw) {
      if (kindRaw !== ServiceKind.BASE && kindRaw !== ServiceKind.ADDON) {
        throw new BadRequestException(
          'kind must be either BASE or ADDON',
        );
      }
      kindNorm = kindRaw as ServiceKind;
    }

    return this.servicesService.findAll({
      locationId: loc,
      kind: kindNorm,
      includeInactive: include,
    });
  }

  private parseBoolean(value?: string): boolean {
    const raw = (value ?? '').trim().toLowerCase();
    return raw === 'true' || raw === '1' || raw === 'yes';
  }
}