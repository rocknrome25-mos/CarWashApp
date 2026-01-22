import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { BookingsModule } from '../bookings/bookings.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { ConfigModule } from '../config/config.module';

@Module({
  imports: [PrismaModule, BookingsModule, ConfigModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
