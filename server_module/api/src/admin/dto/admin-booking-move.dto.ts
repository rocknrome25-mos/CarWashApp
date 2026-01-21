import {
  IsBoolean,
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class AdminBookingMoveDto {
  @IsISO8601()
  newDateTime!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  newBayId?: number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  reason!: string;

  @IsBoolean()
  clientAgreed!: boolean;
}
