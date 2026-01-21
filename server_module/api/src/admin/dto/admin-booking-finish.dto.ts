import { IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminBookingFinishDto {
  @IsOptional()
  @IsISO8601()
  finishedAt?: string; // ISO

  @IsOptional()
  @IsString()
  @MaxLength(500)
  adminNote?: string;
}
