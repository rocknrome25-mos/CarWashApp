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

  @Get()
  getAll(@Query('includeCanceled') includeCanceled?: string) {
    const flag = includeCanceled === '1' || includeCanceled === 'true';
    return this.bookingsService.findAll(flag);
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
    },
  ) {
    return this.bookingsService.create(body);
  }

  // POST /bookings/:id/pay
  // body: { method?: string, kind?: 'DEPOSIT'|'REMAINING'|'EXTRA'|'REFUND', amountRub?: number }
  @Post(':id/pay')
  pay(@Param('id') id: string, @Body() body?: any) {
    return this.bookingsService.pay(id, body);
  }

  @Delete(':id')
  cancel(@Param('id') id: string) {
    return this.bookingsService.cancel(id);
  }
}
