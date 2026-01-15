import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { CarsService } from './cars.service';

@Controller('cars')
export class CarsController {
  constructor(private readonly carsService: CarsService) {}

  // GET /cars?clientId=...
  @Get()
  getAll(@Query('clientId') clientId?: string) {
    const cid = (clientId ?? '').trim();
    if (!cid) {
      throw new BadRequestException('clientId is required');
    }
    return this.carsService.findAll(cid);
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
      clientId?: string | null;
    },
  ) {
    return this.carsService.create(body);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Query('clientId') clientId?: string) {
    const cid = (clientId ?? '').trim();
    if (!cid) {
      throw new BadRequestException('clientId is required');
    }
    return this.carsService.remove(id, cid);
  }
}
