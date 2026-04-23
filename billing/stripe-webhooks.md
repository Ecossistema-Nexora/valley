# Stripe Webhooks

Endpoint sugerido:

`POST /webhooks/stripe`

## Fluxo

1. Validar assinatura com `STRIPE_WEBHOOK_SECRET`
2. Persistir evento bruto em `billing_webhook_events`
3. Processar de forma idempotente
4. Atualizar `billing_subscriptions` e `billing_invoices`
5. Recalcular entitlements do usuario ou PJ responsavel

## Regras

- rejeitar eventos sem assinatura válida
- usar idempotência por `stripe_event_id`
- não atualizar plano diretamente via frontend
- bloquear features premium em caso de `invoice.payment_failed` prolongado
