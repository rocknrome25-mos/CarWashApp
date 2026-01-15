import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';

@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  // GET /bookings?includeCanceled=true&clientId=...
  @Get()
  getAll(
    @Query('includeCanceled') includeCanceled?: string,
    @Query('clientId') clientId?: string,
  ) {
    const flag = includeCanceled === '1' || includeCanceled === 'true';
    return this.bookingsService.findAll(flag, clientId);
  }

  @Post()
  create(
    @Body()
    body: {
      carId: string;
      serviceId: string;
      dateTime: string;
      bayId?: number;
      depositRub?: number;
      bufferMin?: number;
      comment?: string;

      // ✅ добавили
      clientId?: string;
    },
  ) {
    return this.bookingsService.create(body);
  }

  @Post(':id/pay')
  pay(@Param('id') id: string, @Body() body?: any) {
    return this.bookingsService.pay(id, body);
  }

  @Delete(':id')
  cancel(@Param('id') id: string, @Query('clientId') clientId?: string) {
    return this.bookingsService.cancel(id, clientId);
  }
}
