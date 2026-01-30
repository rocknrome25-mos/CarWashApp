import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { BookingsService } from '../bookings/bookings.service';

@Injectable()
export class CronHousekeeperService {
  private readonly logger = new Logger(CronHousekeeperService.name);

  constructor(private readonly bookings: BookingsService) {}

  // Каждый 1 мин: чистим просроченные оплаты и автозавершаем старые ACTIVE
  @Cron('*/1 * * * *')
  async tick() {
    try {
      await this.bookings.cronHousekeeping(); // публичный метод ниже
    } catch (e) {
      this.logger.error(`housekeeping failed: ${e}`);
    }
  }
}
