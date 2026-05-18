export type TenantKind = 'ERP_LOJISTA' | 'RIDER_ENTREGADOR' | 'OMNIVERSE_USUARIO';
export type ApiProvider = 'AMAZON' | 'ALIEXPRESS' | 'CJ_DROPSHIPPING' | 'PRIVATE_STOCK';

export interface TenantTelemetry {
  id: string;
  name: string;
  kind: TenantKind;
  cnpjOrDocument: string;
  health: number;
  latencyMs: number;
  grossProfitBRL: number;
  activeUsers: number;
  incidentCount: number;
  lastSeen: string;
}

export interface ApiConnectorStatus {
  provider: ApiProvider;
  enabled: boolean;
  acl: 'ROOT_ONLY';
  secretEnv: string;
  importedSkus: number;
  syncLagSeconds: number;
  stockMode: 'INFINITE' | 'CONTROLLED' | 'PAUSED';
}

export interface TokenomicsSnapshot {
  vcoinCirculation: number;
  pepitasCirculation: number;
  realProfitBRL: number;
  discountMatrix: Record<'tier10' | 'tier20' | 'tier50', number>;
  auditFlags: string[];
}

export interface SystemLog {
  level: 'INFO' | 'WARN' | 'CRITICAL';
  source: string;
  message: string;
  timestamp: string;
}
