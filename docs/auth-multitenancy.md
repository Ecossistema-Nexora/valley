<!--
PROPOSITO: Documentar o modelo minimo de autenticacao e isolamento multitenant do Valley.
CONTEXTO: Este guia orienta tenants, usuarios, claims JWT e trilhas de auditoria para paineis e APIs.
REGRAS: Todo acesso a dados de negocio deve ser filtrado por tenant_id, com administracao global separada da administracao do tenant.
-->

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
