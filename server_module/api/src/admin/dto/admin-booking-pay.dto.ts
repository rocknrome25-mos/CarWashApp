import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class AdminBookingPayDto {
  // DEPOSIT / REMAINING / EXTRA / REFUND
  @IsString()
  @IsIn(['DEPOSIT', 'REMAINING', 'EXTRA', 'REFUND'])
  kind!: 'DEPOSIT' | 'REMAINING' | 'EXTRA' | 'REFUND';

  @IsInt()
  @Min(0)
  amountRub!: number;

  // CASH / CARD / CONTRACT
  @IsString()
  @IsIn(['CASH', 'CARD', 'CONTRACT'])
  methodType!: 'CASH' | 'CARD' | 'CONTRACT';

  // optional free label: "Terminal", "Sber", "Contract #12"
  @IsOptional()
  @IsString()
  @MaxLength(60)
  methodLabel?: string;

  // reason/comment for audit (recommended)
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
