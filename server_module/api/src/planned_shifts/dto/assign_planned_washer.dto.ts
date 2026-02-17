// C:\dev\carwash\server_module\api\src\planned_shifts\dto\assign_planned_washer.dto.ts
import { IsInt, IsOptional, IsString, Min, Max } from 'class-validator';

export class AssignPlannedWasherDto {
  @IsString()
  washerPhone!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  plannedBayId?: number;

  @IsOptional()
  @IsString()
  note?: string;
}
