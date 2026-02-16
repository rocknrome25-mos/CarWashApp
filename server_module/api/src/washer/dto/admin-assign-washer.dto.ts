import { IsInt, IsString, Min } from 'class-validator';

export class AdminAssignWasherDto {
  @IsString()
  washerPhone!: string;

  @IsInt()
  @Min(1)
  bayId!: number;
}
