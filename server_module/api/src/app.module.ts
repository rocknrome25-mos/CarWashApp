import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { ServicesModule } from './services/services.module';
import { BookingsModule } from './bookings/bookings.module';
import { CarsModule } from './cars/cars.module';

@Module({
  imports: [PrismaModule, ServicesModule, BookingsModule, CarsModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
