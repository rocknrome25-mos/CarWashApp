import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { WsAdapter } from '@nestjs/platform-ws';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // HTTP CORS (для Flutter Web / отладки)
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // ✅ RAW WebSocket adapter (ws), чтобы Flutter мог подключаться через web_socket_channel
  app.useWebSocketAdapter(new WsAdapter(app));

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
