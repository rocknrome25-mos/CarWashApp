import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { CarsService } from './cars.service';

@Controller('cars')
export class CarsController {
  constructor(private readonly carsService: CarsService) {}

  @Get()
  getAll() {
    return this.carsService.findAll();
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
    },
  ) {
    return this.carsService.create(body);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.carsService.remove(id);
  }
}