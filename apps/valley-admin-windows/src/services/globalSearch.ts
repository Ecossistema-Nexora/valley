import { connectors, logs, tenants } from '../domain/mockData';

export function globalSearch(query: string) {
  const q = query.trim().toLowerCase();
  if (!q) return { tenants, connectors, logs };

  const match = (item: unknown) => Object.values(item as Record<string, unknown>).join(' ').toLowerCase().includes(q);

  return {
    tenants: tenants.filter(match),
    connectors: connectors.filter(match),
    logs: logs.filter(match),
  };
}
