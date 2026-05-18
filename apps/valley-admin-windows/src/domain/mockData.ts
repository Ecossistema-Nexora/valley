import type { ApiConnectorStatus, SystemLog, TenantTelemetry, TokenomicsSnapshot } from './types';

export const tenants: TenantTelemetry[] = [
  { id: 'erp-001', name: 'Loja Norte Prime', kind: 'ERP_LOJISTA', cnpjOrDocument: 'TENANT-DOC-001', health: 98, latencyMs: 42, grossProfitBRL: 128450.35, activeUsers: 38, incidentCount: 0, lastSeen: 'online' },
  { id: 'erp-002', name: 'Vale Market', kind: 'ERP_LOJISTA', cnpjOrDocument: 'TENANT-DOC-002', health: 91, latencyMs: 88, grossProfitBRL: 78420.11, activeUsers: 21, incidentCount: 1, lastSeen: 'há 2 min' },
  { id: 'rider-041', name: 'Malha Rider Centro', kind: 'RIDER_ENTREGADOR', cnpjOrDocument: 'RIDER-GROUP-041', health: 87, latencyMs: 120, grossProfitBRL: 18640.0, activeUsers: 142, incidentCount: 2, lastSeen: 'online' },
  { id: 'omni-100', name: 'Omniverse Core Users', kind: 'OMNIVERSE_USUARIO', cnpjOrDocument: 'OMNI-CORE', health: 95, latencyMs: 65, grossProfitBRL: 549200.9, activeUsers: 9502, incidentCount: 0, lastSeen: 'online' },
];

export const connectors: ApiConnectorStatus[] = [
  { provider: 'AMAZON', enabled: true, acl: 'ROOT_ONLY', secretEnv: 'SECRET_AMAZON_CONNECTOR', importedSkus: 1230442, syncLagSeconds: 18, stockMode: 'INFINITE' },
  { provider: 'ALIEXPRESS', enabled: true, acl: 'ROOT_ONLY', secretEnv: 'SECRET_ALIEXPRESS_CONNECTOR', importedSkus: 874900, syncLagSeconds: 31, stockMode: 'INFINITE' },
  { provider: 'CJ_DROPSHIPPING', enabled: true, acl: 'ROOT_ONLY', secretEnv: 'SECRET_CJ_CONNECTOR', importedSkus: 495220, syncLagSeconds: 24, stockMode: 'CONTROLLED' },
  { provider: 'PRIVATE_STOCK', enabled: false, acl: 'ROOT_ONLY', secretEnv: 'SECRET_PRIVATE_STOCK_CONNECTOR', importedSkus: 0, syncLagSeconds: 0, stockMode: 'PAUSED' },
];

export const tokenomics: TokenomicsSnapshot = {
  vcoinCirculation: 45920244,
  pepitasCirculation: 9142022,
  realProfitBRL: 774711.36,
  discountMatrix: { tier10: 0.1, tier20: 0.2, tier50: 0.5 },
  auditFlags: ['ROOT_ONLY_TOKENOMICS', 'DUAL_ECONOMY_AUDIT', 'STOCK_PROFIT_BASED_DISCOUNT'],
};

export const logs: SystemLog[] = [
  { level: 'INFO', source: 'gateway', message: 'Roteamento multi-tenant sincronizado', timestamp: 'agora' },
  { level: 'WARN', source: 'stock-importer', message: 'Conector de dropshipping em modo controlado', timestamp: 'há 3 min' },
  { level: 'CRITICAL', source: 'security', message: 'Segredos externos devem ficar no cofre do backend, nunca no desktop', timestamp: 'há 6 min' },
  { level: 'INFO', source: 'updater', message: 'Barramento OTA em modo silencioso preparado', timestamp: 'há 8 min' },
];
