import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type ContactsConfig = {
  title?: string;
  address?: string;
  phone?: string;
  telegram?: string;
  whatsapp?: string;
  navigatorLink?: string;
  mapsLink?: string;
};

type PublicConfigResponse = {
  locationId: string;
  title: string;
  address: string;
  colorHex: string;
  baysCount: number;

  phone: string;
  telegram: string;
  whatsapp: string;
  navigatorLink: string;
  mapsLink: string;

  features: Record<string, boolean>;
};

@Injectable()
export class ConfigService {
  constructor(private prisma: PrismaService) {}

  private _str(v: unknown, fallback = ''): string {
    const s = (v ?? '').toString().trim();
    return s.length ? s : fallback;
  }

  private _safeContactsParams(params: unknown): ContactsConfig {
    if (!params || typeof params !== 'object' || Array.isArray(params)) {
      return {};
    }

    const p = params as Record<string, unknown>;
    return {
      title: this._str(p.title),
      address: this._str(p.address),
      phone: this._str(p.phone),
      telegram: this._str(p.telegram),
      whatsapp: this._str(p.whatsapp),
      navigatorLink: this._str(p.navigatorLink),
      mapsLink: this._str(p.mapsLink),
    };
  }

  private _normalizeTg(t: string): string {
    const x = this._str(t);
    if (!x) return '';
    return x.startsWith('@') ? x : `@${x}`;
  }

  async getConfigByLocationId(locationId: string): Promise<PublicConfigResponse> {
    const locId = this._str(locationId);
    if (!locId) throw new BadRequestException('locationId is required');

    const loc = await this.prisma.location.findUnique({
      where: { id: locId },
      select: {
        id: true,
        name: true,
        address: true,
        colorHex: true,
        baysCount: true,
        phone: true,
        telegram: true,
        whatsapp: true,
        navigatorLink: true,
        tenantId: true,
      },
    });

    if (!loc) throw new BadRequestException('Location not found');

    const featureRows = await this.prisma.tenantFeature.findMany({
      where: { tenantId: loc.tenantId },
      select: { key: true, enabled: true, params: true },
    });

    const features: Record<string, boolean> = {};
    let contacts: ContactsConfig = {};

    for (const f of featureRows) {
      features[f.key] = f.enabled === true;
      if (f.key === 'CONTACTS' && f.enabled === true) {
        contacts = this._safeContactsParams(f.params);
      }
    }

    const defaultTitle = this._str(loc.name, 'Контакты');
    const defaultAddress = this._str(loc.address, '');

    const title = this._str(contacts.title, defaultTitle);
    const address = this._str(contacts.address, defaultAddress);

    const phone = this._str(contacts.phone, this._str(loc.phone, ''));
    const telegram = this._normalizeTg(
      this._str(contacts.telegram, this._str(loc.telegram, '')),
    );
    const whatsapp = this._str(
      contacts.whatsapp,
      this._str(loc.whatsapp, phone),
    );
    const navigatorLink = this._str(
      contacts.navigatorLink,
      this._str(contacts.mapsLink, this._str(loc.navigatorLink, '')),
    );
    const mapsLink = this._str(contacts.mapsLink, navigatorLink);

    return {
      locationId: loc.id,
      title,
      address,
      colorHex: this._str(loc.colorHex, '#2D9CDB'),
      baysCount: typeof loc.baysCount === 'number' ? loc.baysCount : 2,

      phone,
      telegram,
      whatsapp,
      navigatorLink,
      mapsLink,

      features,
    };
  }

  async isEnabledByLocationId(locationId: string, key: string): Promise<boolean> {
    const locId = this._str(locationId);
    const k = this._str(key);
    if (!locId || !k) return false;

    const loc = await this.prisma.location.findUnique({
      where: { id: locId },
      select: { tenantId: true },
    });
    if (!loc) return false;

    const f = await this.prisma.tenantFeature.findUnique({
      where: { tenantId_key: { tenantId: loc.tenantId, key: k } },
      select: { enabled: true },
    });

    return f?.enabled === true;
  }

  async upsertContactsByLocationId(locationId: string, body: any) {
    const locId = this._str(locationId);
    if (!locId) throw new BadRequestException('locationId is required');

    const loc = await this.prisma.location.findUnique({
      where: { id: locId },
      select: {
        id: true,
        tenantId: true,
        name: true,
        address: true,
        phone: true,
        telegram: true,
        whatsapp: true,
        navigatorLink: true,
      },
    });

    if (!loc) throw new BadRequestException('Location not found');

    const existing = await this.prisma.tenantFeature.findUnique({
      where: { tenantId_key: { tenantId: loc.tenantId, key: 'CONTACTS' } },
      select: { params: true },
    });

    const prev = this._safeContactsParams(existing?.params);

    const next: ContactsConfig = {
      title: this._str(
        body?.title,
        this._str(prev.title, this._str(loc.name, 'Контакты')),
      ),
      address: this._str(
        body?.address,
        this._str(prev.address, this._str(loc.address, '')),
      ),
      phone: this._str(
        body?.phone,
        this._str(prev.phone, this._str(loc.phone, '')),
      ),
      telegram: this._str(
        body?.telegram,
        this._str(prev.telegram, this._str(loc.telegram, '')),
      ),
      whatsapp: this._str(
        body?.whatsapp,
        this._str(prev.whatsapp, this._str(loc.whatsapp, '')),
      ),
      navigatorLink: this._str(
        body?.navigatorLink,
        this._str(prev.navigatorLink, this._str(loc.navigatorLink, '')),
      ),
      mapsLink: this._str(
        body?.mapsLink,
        this._str(
          prev.mapsLink,
          this._str(prev.navigatorLink, this._str(loc.navigatorLink, '')),
        ),
      ),
    };

    const hasAny =
      !!next.title ||
      !!next.address ||
      !!next.phone ||
      !!next.telegram ||
      !!next.whatsapp ||
      !!next.navigatorLink ||
      !!next.mapsLink;

    if (!hasAny) {
      throw new BadRequestException('Contacts payload is empty');
    }

    await this.prisma.tenantFeature.upsert({
      where: { tenantId_key: { tenantId: loc.tenantId, key: 'CONTACTS' } },
      update: { enabled: true, params: next as any },
      create: {
        tenantId: loc.tenantId,
        key: 'CONTACTS',
        enabled: true,
        params: next as any,
      },
      select: { id: true },
    });

    return this.getConfigByLocationId(loc.id);
  }
}