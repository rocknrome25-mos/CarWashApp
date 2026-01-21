import { IsISO8601, IsString } from 'class-validator';

export class AdminCalendarDayDto {
  @IsString()
  locationId!: string;

  // ожидаем "YYYY-MM-DD"
  @IsISO8601({ strict: true })
  date!: string;
}
