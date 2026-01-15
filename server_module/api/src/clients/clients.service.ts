import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ClientGender } from '@prisma/client';

type RegisterBody = {
  phone: string;
  name?: string;
  gender: 'MALE' | 'FEMALE';
  birthDate?: string;
};

@Injectable()
export class ClientsService {
  constructor(private prisma: PrismaService) {}

  private _normalizeRuPhone(raw: string): string {
    const s = (raw ?? '').trim();
    const digits = s.replaceAll(/[^\d]/g, '');

    // допускаем:
    // 10 digits -> +7XXXXXXXXXX
    // 11 digits starting 8 -> +7XXXXXXXXXX
    // 11 digits starting 7 -> +7XXXXXXXXXX
    if (digits.length === 10) return `+7${digits}`;
    if (digits.length === 11 && digits.startsWith('8')) return `+7${digits.substring(1)}`;
    if (digits.length === 11 && digits.startsWith('7')) return `+7${digits}`;
    // fallback: если уже что-то типа +7..., но там могли остаться не только цифры
    if (s.startsWith('+') && digits.length >= 11) return `+${digits}`;
    throw new BadRequestException('Invalid phone');
  }

  private _parseGender(g: string): ClientGender {
    const v = (g ?? '').trim().toUpperCase();
    if (v === 'MALE') return ClientGender.MALE;
    if (v === 'FEMALE') return ClientGender.FEMALE;
    throw new BadRequestException('Invalid gender');
  }

  async register(body: RegisterBody) {
    if (!body || !body.phone) throw new BadRequestException('phone is required');
    if (!body.gender) throw new BadRequestException('gender is required');

    const phone = this._normalizeRuPhone(body.phone);
    const gender = this._parseGender(body.gender);

    const name =
      typeof body.name === 'string' && body.name.trim().length > 0
        ? body.name.trim().slice(0, 60)
        : null;

    let birthDate: Date | null = null;
    if (body.birthDate) {
      const d = new Date(body.birthDate);
      if (isNaN(d.getTime())) throw new BadRequestException('birthDate must be ISO');
      birthDate = d;
    }

    // ✅ для демо: "register" идемпотентный — если уже есть по телефону, вернём/обновим
    const client = await this.prisma.client.upsert({
      where: { phone },
      create: { phone, name, gender, birthDate },
      update: {
        // можно обновлять имя/пол/др при повторной регистрации (это нормально для демо)
        name,
        gender,
        birthDate,
      },
    });

    return client;
  }
}
