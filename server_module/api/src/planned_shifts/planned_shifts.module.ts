// C:\dev\carwash\server_module\api\src\planned_shifts\planned_shifts.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PlannedShiftsController } from './planned_shifts.controller';
import { PlannedShiftsService } from './planned_shifts.service';

@Module({
  imports: [PrismaModule],
  controllers: [PlannedShiftsController],
  providers: [PlannedShiftsService],
})
export class PlannedShiftsModule {}
