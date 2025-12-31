import { Module } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ServicesController } from './services.controller';
import { ServicesService } from './services.service';

@Module({
  controllers: [ServicesController],
  providers: [ServicesService, PrismaService],
})
export class ServicesModule {}
