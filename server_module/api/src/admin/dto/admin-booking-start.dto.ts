import { IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminBookingStartDto {
  @IsOptional()
  @IsISO8601()
  startedAt?: string; // ISO

  @IsOptional()
  @IsString()
  @MaxLength(500)
  adminNote?: string;
}
