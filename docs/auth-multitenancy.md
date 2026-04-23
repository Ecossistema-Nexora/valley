# Auth e Multi-Tenancy

## Modelo sugerido

- `tenants`
- `users`
- `tenant_users`
- `subscriptions`
- `plans`
- `audit_logs`

## JWT

Claims mínimas:
- `sub`
- `tenant_id`
- `role`
- `plan`

## Regras

- Todo acesso a dados de negócio deve ser filtrado por `tenant_id`.
- Admin global separado de admin do tenant.
- Stripe webhook atualiza plano, status e limites por tenant.
