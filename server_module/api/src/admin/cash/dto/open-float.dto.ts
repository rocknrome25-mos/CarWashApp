import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class OpenFloatDto {
  @IsInt()
  @Min(0)
  amountRub!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
