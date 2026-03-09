import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Injectable()
export class AppService {
  constructor(private readonly prisma: PrismaService) {}

  getRootInfo() {
    return {
      ok: true,
      service: 'carwash-api',
      env: process.env.NODE_ENV ?? 'development',
      time: new Date().toISOString(),
    };
  }

  getHealth() {
    return {
      ok: true,
      status: 'up',
      env: process.env.NODE_ENV ?? 'development',
      time: new Date().toISOString(),
    };
  }

  async getDbHealth() {
    await this.prisma.$queryRaw`SELECT 1`;

    return {
      ok: true,
      status: 'up',
      db: 'ok',
      time: new Date().toISOString(),
    };
  }
}