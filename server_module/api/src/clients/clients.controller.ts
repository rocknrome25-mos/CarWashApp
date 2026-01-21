import { Body, Controller, Post } from '@nestjs/common';
import { ClientsService } from './clients.service';

@Controller('clients')
export class ClientsController {
  constructor(private readonly clientsService: ClientsService) {}

  // POST /clients/register
  @Post('register')
  register(
    @Body()
    body: {
      phone: string;
      name?: string;
      gender?: 'MALE' | 'FEMALE'; // ✅ optional
      birthDate?: string; // ISO
    },
  ) {
    return this.clientsService.register(body);
  }
}
