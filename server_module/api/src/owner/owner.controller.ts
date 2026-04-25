import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { OwnerService } from './owner.service';

@Controller('owner')
export class OwnerController {
  constructor(private readonly ownerService: OwnerService) {}

  @Get('summary')
  getSummary(@Query('period') period?: string) {
    return this.ownerService.getSummary(period);
  }

  @Get('chart')
  getChart(@Query('period') period?: string) {
    return this.ownerService.getChart(period);
  }

  @Get('finance')
  getFinance(@Query('period') period?: string) {
    return this.ownerService.getFinance(period);
  }

  @Get('alerts')
  getOwnerAlerts(
    @Query('period') period?: string,
    @Query('unreadOnly') unreadOnly?: string,
    @Query('limit') limit?: string,
  ) {
    return this.ownerService.getOwnerAlerts({
      period,
      unreadOnly,
      limit,
    });
  }

  @Post('alerts/:id/read')
  markOwnerAlertRead(@Param('id') id: string) {
    return this.ownerService.markOwnerAlertRead(id);
  }

  @Get('suspicious-events')
  getSuspiciousEvents(
    @Query('period') period?: string,
    @Query('type') type?: string,
    @Query('userId') userId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.ownerService.getSuspiciousEvents({
      period,
      type,
      userId,
      limit,
    });
  }

  @Get('employees')
  getEmployees() {
    return this.ownerService.getEmployees();
  }

  @Get('employees/analytics')
  getEmployeeAnalytics(@Query('period') period?: string) {
    return this.ownerService.getEmployeeAnalytics(period);
  }

  @Post('employees')
  createEmployee(
    @Body()
    body: {
      name?: string;
      phone?: string;
      role?: string;
      password?: string;
    },
  ) {
    return this.ownerService.createEmployee(body);
  }

  @Patch('employees/:id')
  updateEmployee(
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      phone?: string;
    },
  ) {
    return this.ownerService.updateEmployee(id, body);
  }

  @Post('employees/:id/toggle')
  toggleEmployee(@Param('id') id: string) {
    return this.ownerService.toggleEmployee(id);
  }

  @Post('employees/:id/reset-password')
  resetEmployeePassword(
    @Param('id') id: string,
    @Body()
    body: {
      password?: string;
    },
  ) {
    return this.ownerService.resetEmployeePassword(id, body);
  }

  @Post('services')
  createService(
    @Body()
    body: {
      name?: string;
      description?: string;
      kind?: 'BASE' | 'ADDON';
      imageKey?:
        | 'EXTERIOR_WASH'
        | 'FULL_WASH'
        | 'WAX'
        | 'TIRES'
        | 'INTERIOR'
        | 'LEATHER_CARE';
      priceRub?: number;
      durationMin?: number;
      hasBodyTypePricing?: boolean;
      bodyTypePrices?: Array<{
        bodyType?: string;
        priceRub?: number;
      }>;
      includedAddonIds?: string[];
      isPublished?: boolean;
    },
  ) {
    return this.ownerService.createService(body);
  }

  @Patch('services/:id')
  updateService(
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      description?: string;
      imageKey?:
        | 'EXTERIOR_WASH'
        | 'FULL_WASH'
        | 'WAX'
        | 'TIRES'
        | 'INTERIOR'
        | 'LEATHER_CARE';
      priceRub?: number;
      durationMin?: number;
      hasBodyTypePricing?: boolean;
      bodyTypePrices?: Array<{
        bodyType?: string;
        priceRub?: number;
      }>;
      includedAddonIds?: string[];
      isPublished?: boolean;
    },
  ) {
    return this.ownerService.updateService(id, body);
  }

  @Post('services/:id/toggle')
  toggleService(@Param('id') id: string) {
    return this.ownerService.toggleService(id);
  }

  @Get('settings')
  getSettings() {
    return this.ownerService.getSettings();
  }

  @Patch('settings')
  updateSettings(
    @Body()
    body: {
      communication?: {
        washStartTemplate?: string;
        washFinishTemplate?: string;
        campaigns?: {
          promotionsEnabled?: boolean;
          discountsEnabled?: boolean;
          holidayGreetingsEnabled?: boolean;
        };
      };
      monitoring?: {
        suspiciousAuditTypes?: string[];
        notifyPhone?: string;
        notifyTelegram?: string;
        notifyPush?: boolean;
      };
    },
  ) {
    return this.ownerService.updateSettings(body);
  }

  @Get('compensation-settings')
  getCompensationSettings() {
    return this.ownerService.getCompensationSettings();
  }

  @Patch('compensation-settings')
  updateCompensationSettings(
    @Body()
    body: {
      washerBasePercent?: number;
      washerAddonPercent?: number;
      adminBaseSalaryRub?: number;
      adminBasePercent?: number;
      adminAddonPercent?: number;
      adminUpsellPercent?: number;
    },
  ) {
    return this.ownerService.updateCompensationSettings(body);
  }

  @Post('change-password')
  changeOwnerPassword(
    @Body()
    body: {
      password?: string;
    },
  ) {
    return this.ownerService.changeOwnerPassword(body);
  }
}