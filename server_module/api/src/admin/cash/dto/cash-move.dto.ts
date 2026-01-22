import { IsInt, IsNotEmpty, IsString, MaxLength, Min } from 'class-validator';

export class CashMoveDto {
  @IsInt()
  @Min(0)
  amountRub!: number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  note!: string;
}
