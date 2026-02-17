// C:\dev\carwash\server_module\api\src\planned_shifts\dto\update_planned_shift.dto.ts
import { IsOptional, IsString, MinLength } from 'class-validator';

export class UpdatePlannedShiftDto {
  @IsOptional()
  @IsString()
  @MinLength(8)
  startAt?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  endAt?: string;

  @IsOptional()
  @IsString()
  status?: 'DRAFT' | 'PUBLISHED' | 'CANCELED';

  @IsOptional()
  @IsString()
  note?: string;
}
