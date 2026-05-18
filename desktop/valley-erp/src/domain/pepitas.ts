import type { PepitaGift } from './merchant-schema';

export const PEPITA_GIFT_OPTIONS: PepitaGift[] = [
  { pepitas: 1, brlValueCents: 300, confirmedByMerchant: true },
  { pepitas: 10, brlValueCents: 3000, confirmedByMerchant: true },
  { pepitas: 100, brlValueCents: 30000, confirmedByMerchant: true },
];

export function pepitaGiftLabel(gift: PepitaGift): string {
  const brl = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(gift.brlValueCents / 100);
  return `${gift.pepitas} pepita${gift.pepitas > 1 ? 's' : ''} (${brl})`;
}

export function requiresHighValueConfirmation(gift: PepitaGift): boolean {
  return gift.pepitas >= 10;
}
