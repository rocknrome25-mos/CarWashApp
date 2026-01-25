import { IsInt, IsString, MaxLength, Min } from 'class-validator';

export class AdminBookingDiscountDto {
  @IsInt()
  @Min(0)
  discountRub!: number;

  @IsString()
  @MaxLength(200)
  reason!: string;
}
