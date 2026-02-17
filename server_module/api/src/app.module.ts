// C:\dev\carwash\server_module\api\src\app.module.ts
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

// ✅ existing
import { WasherModule } from './washer/washer.module';

// ✅ NEW: planned schedule module (admin/planned-shifts)
import { PlannedShiftsModule } from './planned_shifts/planned_shifts.module';

@Module({
  imports: [
    // ⬇️ scheduler для крон-задач
    ScheduleModule.forRoot(),

    PrismaModule,
    ServicesModule,
    BookingsModule,
    CarsModule,
    ClientsModule,
    LocationsModule,
    AdminModule,
    ConfigModule,

    // ✅ modules
    WasherModule,
    PlannedShiftsModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    // ⬇️ наш планировщик
    CronHousekeeperService,
  ],
})
export class AppModule {}
