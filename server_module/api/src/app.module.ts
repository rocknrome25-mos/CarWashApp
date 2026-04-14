import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';

import { AdminModule } from './admin/admin.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { BookingsModule } from './bookings/bookings.module';
import { CarsModule } from './cars/cars.module';
import { ClientsModule } from './clients/clients.module';
import { LocationsModule } from './locations/locations.module';
import { PrismaModule } from './prisma/prisma.module';
import { ServicesModule } from './services/services.module';
import { ConfigModule } from './config/config.module';
import { CronHousekeeperService } from '../src/cron/cron-housekeeper.service';
import { WasherModule } from './washer/washer.module';
import { PlannedShiftsModule } from './planned_shifts/planned_shifts.module';
import { OwnerModule } from './owner/owner.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),

    PrismaModule,
    ServicesModule,
    BookingsModule,
    CarsModule,
    ClientsModule,
    LocationsModule,
    AdminModule,
    ConfigModule,
    WasherModule,
    PlannedShiftsModule,
    OwnerModule,
  ],
  controllers: [AppController],
  providers: [AppService, CronHousekeeperService],
})
export class AppModule {}