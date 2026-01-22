import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CloseCashDto {
  @IsInt()
  @Min(0)
  countedRub!: number;

  @IsInt()
  @Min(0)
  handoverRub!: number;

  @IsInt()
  @Min(0)
  keepRub!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
