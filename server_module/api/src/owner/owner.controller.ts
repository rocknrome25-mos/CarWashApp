import { Body, Controller, Get, Post, Query } from '@nestjs/common';
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
}