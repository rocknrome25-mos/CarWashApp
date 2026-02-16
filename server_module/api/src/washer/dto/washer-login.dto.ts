// C:\dev\carwash\server_module\api\src\washer\dto\washer-login.dto.ts
import { IsString, MinLength } from 'class-validator';

export class WasherLoginDto {
  @IsString()
  @MinLength(3)
  phone!: string;
}
