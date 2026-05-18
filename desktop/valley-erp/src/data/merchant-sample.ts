import type { LocalCategory, MerchantProduct, PhysicalFreight, ProductVariation, SaleOrder } from '../domain/merchant-schema';

export const categories: LocalCategory[] = [
  { id: 'cat-001', merchantId: 'merchant-local-001', name: 'Mercearia', slug: 'mercearia', active: true },
  { id: 'cat-002', merchantId: 'merchant-local-001', name: 'Bebidas', slug: 'bebidas', active: true },
  { id: 'cat-003', merchantId: 'merchant-local-001', name: 'Higiene', slug: 'higiene', active: true },
];

export const products: MerchantProduct[] = [
  {
    id: 'prd-001',
    merchantId: 'merchant-local-001',
    categoryId: 'cat-001',
    sku: 'LOC-ARZ-001',
    name: 'Arroz Tipo 1 5kg',
    description: 'Produto físico local controlado pelo lojista.',
    brand: 'Valley Local',
    status: 'ACTIVE',
    localOnly: true,
    createdAt: '2026-05-18T08:00:00-03:00',
    updatedAt: '2026-05-18T08:00:00-03:00',
  },
  {
    id: 'prd-002',
    merchantId: 'merchant-local-001',
    categoryId: 'cat-002',
    sku: 'LOC-CAF-002',
    name: 'Café Especial 500g',
    description: 'SKU local com controle de estoque físico.',
    brand: 'Valley Local',
    status: 'ACTIVE',
    localOnly: true,
    createdAt: '2026-05-18T08:05:00-03:00',
    updatedAt: '2026-05-18T08:05:00-03:00',
  },
];

export const variations: ProductVariation[] = [
  {
    id: 'var-001',
    productId: 'prd-001',
    sku: 'LOC-ARZ-001-5KG',
    barcode: '7890000000011',
    attributes: { peso: '5kg' },
    costPriceCents: 1890,
    salePriceCents: 2590,
    physicalStockQty: 42,
    reservedQty: 3,
    minStockQty: 10,
    locationCode: 'A1-03',
  },
  {
    id: 'var-002',
    productId: 'prd-002',
    sku: 'LOC-CAF-002-500G',
    barcode: '7890000000028',
    attributes: { peso: '500g', moagem: 'media' },
    costPriceCents: 2190,
    salePriceCents: 3490,
    physicalStockQty: 18,
    reservedQty: 2,
    minStockQty: 8,
    locationCode: 'B2-01',
  },
];

export const orders: SaleOrder[] = [
  {
    id: 'ord-1001',
    merchantId: 'merchant-local-001',
    customerName: 'Cliente Balcao',
    status: 'PAID',
    subtotalCents: 6080,
    freightCents: 1200,
    discountCents: 0,
    totalCents: 7280,
  },
  {
    id: 'ord-1002',
    merchantId: 'merchant-local-001',
    customerName: 'Cliente Fidelidade',
    status: 'COMPLETED',
    subtotalCents: 3490,
    freightCents: 0,
    discountCents: 300,
    totalCents: 3190,
    pepitaGift: { pepitas: 10, brlValueCents: 3000, confirmedByMerchant: true },
    completedAt: '2026-05-18T10:15:00-03:00',
  },
];

export const freights: PhysicalFreight[] = [
  {
    id: 'frt-001',
    merchantId: 'merchant-local-001',
    saleOrderId: 'ord-1001',
    carrierName: 'Motoboy Local',
    serviceName: 'Entrega expressa bairro',
    pickupWindow: 'Hoje 14:00-16:00',
    declaredValueCents: 7280,
    freightCostCents: 900,
    customerChargedCents: 1200,
    status: 'BOOKED',
  },
];
