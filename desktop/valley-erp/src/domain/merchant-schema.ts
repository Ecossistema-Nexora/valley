export type MoneyCents = number;

export type LocalCategory = {
  id: string;
  merchantId: string;
  parentId?: string;
  name: string;
  slug: string;
  active: boolean;
};

export type MerchantProduct = {
  id: string;
  merchantId: string;
  categoryId: string;
  sku: string;
  name: string;
  description: string;
  brand?: string;
  status: 'ACTIVE' | 'DRAFT' | 'ARCHIVED';
  localOnly: true;
  createdAt: string;
  updatedAt: string;
};

export type ProductVariation = {
  id: string;
  productId: string;
  sku: string;
  barcode?: string;
  attributes: Record<string, string>;
  costPriceCents: MoneyCents;
  salePriceCents: MoneyCents;
  promoPriceCents?: MoneyCents;
  physicalStockQty: number;
  reservedQty: number;
  minStockQty: number;
  locationCode?: string;
};

export type SaleOrderStatus = 'DRAFT' | 'PAID' | 'PICKING' | 'SHIPPED' | 'COMPLETED' | 'CANCELLED';

export type PepitaGift = {
  pepitas: 1 | 10 | 100;
  brlValueCents: 300 | 3000 | 30000;
  confirmedByMerchant: boolean;
};

export type SaleOrder = {
  id: string;
  merchantId: string;
  customerName: string;
  status: SaleOrderStatus;
  subtotalCents: MoneyCents;
  freightCents: MoneyCents;
  discountCents: MoneyCents;
  totalCents: MoneyCents;
  pepitaGift?: PepitaGift;
  completedAt?: string;
};

export type PhysicalFreight = {
  id: string;
  merchantId: string;
  saleOrderId: string;
  carrierName: string;
  serviceName: string;
  trackingCode?: string;
  pickupWindow?: string;
  declaredValueCents: MoneyCents;
  freightCostCents: MoneyCents;
  customerChargedCents: MoneyCents;
  status: 'QUOTE' | 'BOOKED' | 'IN_TRANSIT' | 'DELIVERED' | 'FAILED';
};
