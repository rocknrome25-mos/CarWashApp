import { IsString, MinLength } from 'class-validator';

export class AdminLoginDto {
  @IsString()
  @MinLength(8)
  phone!: string; // "+7999..."
}
