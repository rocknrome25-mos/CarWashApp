import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { BookingsModule } from '../bookings/bookings.module';
import { ConfigModule } from '../config/config.module';

import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

import { AdminBookingsController } from './admin_bookings.controller';
import { AdminBookingsService } from './admin_bookings.service';

@Module({
  imports: [PrismaModule, BookingsModule, ConfigModule],
  controllers: [AdminController, AdminBookingsController],
  providers: [AdminService, AdminBookingsService],
})
export class AdminModule {}
