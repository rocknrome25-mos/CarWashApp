import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { WsAdapter } from '@nestjs/platform-ws';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // ✅ Global validation for DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // HTTP CORS (для Flutter Web / отладки)
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // ✅ Serve uploaded files
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
  });

  // ✅ RAW WebSocket adapter (ws), чтобы Flutter мог подключаться через web_socket_channel
  app.useWebSocketAdapter(new WsAdapter(app));

  await app.listen(process.env.PORT ?? 3000);
}

bootstrap();
