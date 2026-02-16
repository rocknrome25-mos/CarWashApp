import { IsString } from 'class-validator';

export class AdminUnassignWasherDto {
  @IsString()
  washerPhone!: string;
}
