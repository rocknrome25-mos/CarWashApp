import { IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminBayOpenDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
