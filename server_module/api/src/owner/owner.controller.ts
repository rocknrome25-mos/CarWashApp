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

  @Get('employees')
  getEmployees() {
    return this.ownerService.getEmployees();
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
}