import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getRoot() {
    return this.appService.getRootInfo();
  }

  @Get('health')
  getHealth() {
    return this.appService.getHealth();
  }

  @Get('health/db')
  async getDbHealth() {
    return this.appService.getDbHealth();
  }
}