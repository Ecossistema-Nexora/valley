export type MerchantRole =
  | 'MERCHANT_OWNER'
  | 'MERCHANT_MANAGER'
  | 'MERCHANT_STOCK'
  | 'MERCHANT_CASHIER';

export type MerchantPermission =
  | 'LOCAL_STOCK_READ'
  | 'LOCAL_STOCK_WRITE'
  | 'LOCAL_CATEGORY_WRITE'
  | 'LOCAL_SALE_WRITE'
  | 'LOCAL_FREIGHT_WRITE'
  | 'LOCAL_PEPITA_GIFT';

export const MERCHANT_PERMISSIONS: Record<MerchantRole, MerchantPermission[]> = {
  MERCHANT_OWNER: [
    'LOCAL_STOCK_READ',
    'LOCAL_STOCK_WRITE',
    'LOCAL_CATEGORY_WRITE',
    'LOCAL_SALE_WRITE',
    'LOCAL_FREIGHT_WRITE',
    'LOCAL_PEPITA_GIFT',
  ],
  MERCHANT_MANAGER: [
    'LOCAL_STOCK_READ',
    'LOCAL_STOCK_WRITE',
    'LOCAL_CATEGORY_WRITE',
    'LOCAL_SALE_WRITE',
    'LOCAL_FREIGHT_WRITE',
    'LOCAL_PEPITA_GIFT',
  ],
  MERCHANT_STOCK: ['LOCAL_STOCK_READ', 'LOCAL_STOCK_WRITE', 'LOCAL_CATEGORY_WRITE'],
  MERCHANT_CASHIER: ['LOCAL_STOCK_READ', 'LOCAL_SALE_WRITE', 'LOCAL_PEPITA_GIFT'],
};

export const MASTER_ONLY_FEATURES = [
  'AMAZON_IMPORT',
  'ALIEXPRESS_IMPORT',
  'ALIBABA_IMPORT',
  'CJDROPSHIPPING_IMPORT',
  'DROPSHIPPING_CATALOG_SYNC',
  'EXTERNAL_MARKETPLACE_KEYS',
] as const;

export function canMerchant(role: MerchantRole, permission: MerchantPermission): boolean {
  return MERCHANT_PERMISSIONS[role].includes(permission);
}

export function mustHideForMerchant(feature: string): boolean {
  return MASTER_ONLY_FEATURES.includes(feature as (typeof MASTER_ONLY_FEATURES)[number]);
}
