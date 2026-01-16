import { Injectable, Logger } from '@nestjs/common';
import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import type { Server, WebSocket } from 'ws';

type BookingChangedEvent = {
  type: 'booking.changed';
  bayId: number;
  at: string; // ISO UTC
};

@WebSocketGateway({ path: '/ws' })
@Injectable()
export class BookingsGateway {
  private readonly log = new Logger(BookingsGateway.name);

  @WebSocketServer()
  server!: Server;

  emitBookingChanged(bayId: number) {
    const payload: BookingChangedEvent = {
      type: 'booking.changed',
      bayId,
      at: new Date().toISOString(),
    };

    const msg = JSON.stringify(payload);

    if (!this.server) return;

    // broadcast to all connected clients
    this.server.clients.forEach((client: WebSocket) => {
      // ws.OPEN === 1
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const anyClient: any = client;
      if (anyClient.readyState === 1) {
        client.send(msg);
      }
    });
  }
}
