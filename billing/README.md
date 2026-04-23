# Billing

Extensao de billing Stripe orientada ao nucleo Valley, sem recriar identidade paralela.

## Componentes

- `schema.sql`: extensao relacional de billing ligada a `public.users` e `public.wallets`
- `stripe-webhooks.md`: eventos obrigatórios
- `entitlements.md`: matriz de planos
- `checkout-session.example.json`: payload de exemplo

## Regra de modelagem

- nao criar tabela `users` nova para billing
- todo billing precisa apontar para `public.users.user_id`
- cobranca e entitlement podem referenciar `wallet_id` quando o plano impactar `PAY`

## Eventos mínimos

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`
