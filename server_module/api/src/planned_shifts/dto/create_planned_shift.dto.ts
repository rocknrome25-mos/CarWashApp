// C:\dev\carwash\server_module\api\src\planned_shifts\dto\create_planned_shift.dto.ts
import { IsOptional, IsString, MinLength } from 'class-validator';

export class CreatePlannedShiftDto {
  @IsString()
  @MinLength(8)
  startAt!: string; // ISO

  @IsString()
  @MinLength(8)
  endAt!: string; // ISO

  @IsOptional()
  @IsString()
  note?: string;
}
