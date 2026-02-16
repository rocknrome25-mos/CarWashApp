import { IsInt, Max, Min } from 'class-validator';

export class AdminMoveWasherDto {
  @IsInt()
  @Min(1)
  @Max(20)
  bayId!: number;
}
