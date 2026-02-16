// C:\dev\carwash\server_module\api\src\washer\washer.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { WasherController } from './washer.controller';
import { WasherService } from './washer.service';

@Module({
  imports: [PrismaModule],
  controllers: [WasherController],
  providers: [WasherService],
})
export class WasherModule {}
