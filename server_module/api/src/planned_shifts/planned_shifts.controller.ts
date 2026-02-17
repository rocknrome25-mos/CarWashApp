// C:\dev\carwash\server_module\api\src\planned_shifts\planned_shifts.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { PlannedShiftsService } from './planned_shifts.service';
import { CreatePlannedShiftDto } from './dto/create_planned_shift.dto';
import { UpdatePlannedShiftDto } from './dto/update_planned_shift.dto';
import { AssignPlannedWasherDto } from './dto/assign_planned_washer.dto';

@Controller('admin/planned-shifts')
export class PlannedShiftsController {
  constructor(private readonly svc: PlannedShiftsService) {}

  @Get()
  list(
    @Headers('x-user-id') userId?: string,
    @Query('from') fromRaw?: string,
    @Query('to') toRaw?: string,
  ) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');

    const from = (fromRaw ?? '').trim();
    const to = (toRaw ?? '').trim();
    if (!from || !to) throw new BadRequestException('from and to are required');

    return this.svc.list(uid, from, to);
  }

  @Post()
  create(
    @Headers('x-user-id') userId?: string,
    @Body() dto: CreatePlannedShiftDto = {} as CreatePlannedShiftDto,
  ) {
    const uid = (userId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    return this.svc.create(uid, dto);
  }

  @Patch(':id')
  update(
    @Headers('x-user-id') userId?: string,
    @Param('id') id?: string,
    @Body() dto: UpdatePlannedShiftDto = {} as UpdatePlannedShiftDto,
  ) {
    const uid = (userId ?? '').trim();
    const pid = (id ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!pid) throw new BadRequestException('id is required');
    return this.svc.update(uid, pid, dto);
  }

  @Post(':id/publish')
  publish(
    @Headers('x-user-id') userId?: string,
    @Param('id') id?: string,
  ) {
    const uid = (userId ?? '').trim();
    const pid = (id ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!pid) throw new BadRequestException('id is required');
    return this.svc.publish(uid, pid);
  }

  @Post(':id/assign-washer')
  assignWasher(
    @Headers('x-user-id') userId?: string,
    @Param('id') id?: string,
    @Body() dto: AssignPlannedWasherDto = {} as AssignPlannedWasherDto,
  ) {
    const uid = (userId ?? '').trim();
    const pid = (id ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!pid) throw new BadRequestException('id is required');
    return this.svc.assignWasher(uid, pid, dto);
  }

  // ✅ remove washer from planned shift (washerId = userId of washer)
  @Delete(':id/washers/:washerId')
  removeWasher(
    @Headers('x-user-id') userId?: string,
    @Param('id') id?: string,
    @Param('washerId') washerId?: string,
  ) {
    const uid = (userId ?? '').trim();
    const pid = (id ?? '').trim();
    const wid = (washerId ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!pid) throw new BadRequestException('id is required');
    if (!wid) throw new BadRequestException('washerId is required');
    return this.svc.removeWasher(uid, pid, wid);
  }

  // ✅ "Delete planned shift" = soft-cancel
  @Delete(':id')
  deletePlannedShift(
    @Headers('x-user-id') userId?: string,
    @Param('id') id?: string,
  ) {
    const uid = (userId ?? '').trim();
    const pid = (id ?? '').trim();
    if (!uid) throw new BadRequestException('x-user-id is required');
    if (!pid) throw new BadRequestException('id is required');
    return this.svc.deletePlannedShift(uid, pid);
  }
}
