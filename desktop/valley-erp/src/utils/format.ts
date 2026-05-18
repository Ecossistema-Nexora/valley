export const brlFormatter = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});

export const numberFormatter = new Intl.NumberFormat('pt-BR');

export function formatMoney(cents: number): string {
  return brlFormatter.format(cents / 100);
}

export function formatQty(value: number): string {
  return numberFormatter.format(value);
}

export function formatPercent(value: number): string {
  return new Intl.NumberFormat('pt-BR', { style: 'percent', maximumFractionDigits: 0 }).format(value);
}
