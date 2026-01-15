import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { CarsService } from './cars.service';

@Controller('cars')
export class CarsController {
  constructor(private readonly carsService: CarsService) {}

  // GET /cars?clientId=...
  @Get()
  getAll(@Query('clientId') clientId?: string) {
    return this.carsService.findAll(clientId);
  }

  @Post()
  create(
    @Body()
    body: {
      makeDisplay: string;
      modelDisplay: string;
      plateDisplay: string;
      year?: number | null;
      color?: string | null;
      bodyType?: string | null;

      // ✅ добавили
      clientId?: string | null;
    },
  ) {
    return this.carsService.create(body);
  }

  @Delete(':id')
  remove(
    @Param('id') id: string,
    @Query('clientId') clientId?: string,
  ) {
    return this.carsService.remove(id, clientId);
  }
}
