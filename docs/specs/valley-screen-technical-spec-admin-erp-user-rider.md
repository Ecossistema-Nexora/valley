# Valley — Especificação Técnica 100% Fechada por Tela

Versão: 1.0  
Status: contrato funcional/técnico para produto, design, backend, frontend, QA e dados  
Superfícies: Admin, Lojista / Valley ERP, Usuário / APK Android, Entregador / APK Android  
Documento relacionado: `docs/specs/valley-operational-spec-admin-erp-user-rider.md`

---

## 1. Objetivo

Este documento fecha a especificação de implementação por tela. Cada tela possui:

- wireframe textual;
- tabela de campos;
- validações frontend e backend;
- permissões por persona;
- APIs necessárias;
- eventos gerados;
- tabelas impactadas;
- notificações;
- estados vazios, loading e erro;
- regras de auditoria e compliance.

O documento deve ser usado como contrato entre produto, UX/UI, frontend Flutter/Web, backend/API, QA, dados, segurança e operações.

---

## 2. Convenções globais

### 2.1 Personas e códigos

| Código | Persona | Descrição |
|---|---|---|
| `ADMIN_SUPERADMIN` | Superadmin | Pode ler, escrever, aprovar, suspender, reprocessar e auditar tudo. |
| `ADMIN_OPERATOR` | Operador | Pode operar filas, usuários, incidentes e pedidos conforme permissão. |
| `ADMIN_ANALYST` | Analista | Pode ler, exportar e analisar; escrita restrita. |
| `ADMIN_VIEWER` | Visualizador | Somente leitura. |
| `MERCHANT_OWNER` | Dono lojista | Administra a empresa, produtos, estoque, anúncios, pedidos e billing da própria conta. |
| `MERCHANT_STAFF` | Colaborador lojista | Opera catálogo, pedidos e estoque conforme permissão interna. |
| `USER_PF` | Usuário final | Compra, paga, usa wallet, Helena, segurança, pedidos e mobilidade. |
| `RIDER` | Entregador/motorista | Opera disponibilidade, ofertas, coleta, rota, entrega, ganhos e segurança. |
| `SYSTEM` | Sistema | Jobs, webhooks, automações e integrações. |

### 2.2 Padrão de API

- Todas as APIs REST devem usar JSON.
- Todas as requisições mutáveis devem aceitar `Idempotency-Key`.
- Todas as respostas devem incluir `trace_id`.
- Todas as respostas paginadas devem usar `page`, `page_size`, `total`, `items`.
- Datas devem trafegar em ISO-8601 UTC.
- Valores monetários BRL devem trafegar como decimal string ou inteiro em centavos no gateway, mas persistir conforme DDL decimal.
- Campos JSONB devem trafegar como objetos válidos.

### 2.3 Estados padrão de tela

Toda tela deve implementar:

| Estado | Regra |
|---|---|
| Loading inicial | Skeleton ou shimmer, sem layout shift agressivo. |
| Loading de ação | Botão com spinner e ação bloqueada contra duplo clique. |
| Estado vazio | Mensagem clara, CTA primário e CTA secundário quando aplicável. |
| Erro recuperável | Mensagem, código, `trace_id`, botão tentar novamente. |
| Erro de permissão | Mensagem sem vazar dados, CTA para voltar. |
| Erro de validação | Campo destacado, mensagem objetiva, foco no primeiro erro. |
| Offline mobile | Banner persistente, fila local apenas para ações permitidas. |
| Sucesso | Toast/snackbar e atualização otimista somente quando segura. |

### 2.4 Auditoria global

Deve gerar `admin_action_audit` ou evento equivalente sempre que houver:

- alteração de status de conta;
- aprovação/reprovação KYC/KYB;
- alteração de permissão;
- alteração de regra de negócio;
- reprocessamento de webhook;
- cancelamento/reembolso/disputa;
- acesso break-glass;
- bloqueio/desbloqueio de usuário, lojista ou rider;
- alteração de dados financeiros, wallet, billing ou split;
- operação manual em estoque ou pedido.

### 2.5 Compliance global

- Dados sensíveis devem ser mascarados por padrão.
- Documento pessoal, CNPJ, telefone e e-mail devem ter logs protegidos.
- Biometria nunca deve expor template bruto; apenas hash/metadados.
- Acesso admin a conversa, memória, localização, documento ou incidente sensível deve exigir motivo.
- Exportação deve registrar ator, filtros, quantidade e finalidade.

---

# 3. Admin Web

## A-01 — Login Admin

### Wireframe textual

```text
[Logo Valley Admin]
[Ambiente: Sandbox | Homologação | Produção]
[Campo: Usuário ou e-mail]
[Campo: Senha]
[Campo condicional: Código 2FA]
[Checkbox: Lembrar dispositivo]
[Botão primário: Entrar]
[Link: Recuperar acesso]
[Alertas: credencial inválida | conta inativa | 2FA obrigatório | ambiente produção]
```

### Campos

| Campo UI | Tipo | Obrigatório | Origem | Destino |
|---|---|---:|---|---|
| Ambiente | select | sim | UI | sessão/auth context |
| Usuário/e-mail | text/email | sim | usuário | `admin_users.username` lookup |
| Senha | password | sim | usuário | verificação contra `password_hash` |
| Código 2FA | numeric text | condicional | usuário | serviço MFA |
| Lembrar dispositivo | boolean | não | usuário | cookie/token seguro |

### Validações frontend

- Usuário/e-mail não pode ser vazio.
- Senha não pode ser vazia.
- Código 2FA deve ser numérico quando exibido.
- Em produção, mostrar confirmação visual de ambiente.

### Validações backend

- `admin_users.is_active = true`.
- Hash de senha válido.
- Conta vinculada a `users.user_id` ativo.
- 2FA válido quando política exigir.
- Rate limit por IP, usuário e device fingerprint.

### Permissões

| Persona | Acesso |
|---|---|
| `ADMIN_SUPERADMIN` | sim |
| `ADMIN_OPERATOR` | sim |
| `ADMIN_ANALYST` | sim |
| `ADMIN_VIEWER` | sim |
| demais | não |

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/admin/auth/login` | Autenticar admin. |
| POST | `/api/admin/auth/mfa/verify` | Validar 2FA. |
| POST | `/api/admin/auth/recover` | Iniciar recuperação. |
| POST | `/api/admin/auth/logout` | Encerrar sessão. |

### Eventos gerados

- `admin.auth.login_succeeded`
- `admin.auth.login_failed`
- `admin.auth.mfa_required`
- `admin.auth.password_recovery_requested`

### Tabelas impactadas

- `admin_users`
- `users`
- `admin_action_audit`

### Notificações

- E-mail/push interno em login suspeito.
- Alerta para Superadmin em múltiplas falhas.

### Estados

- Loading: botão Entrar bloqueado.
- Vazio: não aplicável.
- Erro: credencial inválida, conta inativa, MFA inválido, sem permissão.

### Auditoria/compliance

- Registrar IP, user agent, ambiente, resultado e `trace_id`.
- Nunca registrar senha ou código 2FA.

---

## A-02 — Dashboard Executivo Admin

### Wireframe textual

```text
[Header: busca global | ambiente | usuário | notificações]
[Cards KPI: usuários | lojistas | riders | pedidos | GMV | receita | incidentes]
[Filtros: período | módulo | região | domínio | status | tier]
[Gráfico: pedidos por domínio]
[Gráfico: status de pedidos]
[Tabela: incidentes críticos]
[Tabela: módulos com pendência]
[Tabela: integrações com erro]
[Botões: Atualizar | Exportar | Criar incidente | Abrir runbook]
```

### Campos

| Campo UI | Tipo | Origem | Destino |
|---|---|---|---|
| Período | date range | admin | query dashboard |
| Módulo | select | `module_catalog` | query dashboard |
| Região | select/text | `users.ops_region_code` | query dashboard |
| Domínio | select | `orders.order_domain` | query dashboard |
| Status | multi-select | entidades diversas | query dashboard |
| Tier | select | manifesto/admin | query dashboard |

### Validações frontend

- Data final não pode ser menor que data inicial.
- Exportação exige filtros definidos quando volume for alto.

### Validações backend

- Aplicar permissões por `admin_permissions`.
- Limitar período máximo para consultas pesadas.
- Mascarar dados sensíveis para `VIEWER` e `ANALYST`.

### Permissões

| Persona | Ler | Exportar | Criar incidente |
|---|---:|---:|---:|
| `ADMIN_SUPERADMIN` | sim | sim | sim |
| `ADMIN_OPERATOR` | sim | sim, se permitido | sim |
| `ADMIN_ANALYST` | sim | sim, se permitido | não |
| `ADMIN_VIEWER` | sim | não | não |

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/dashboard/summary` | KPIs consolidados. |
| GET | `/api/admin/dashboard/orders-by-domain` | Série por domínio. |
| GET | `/api/admin/dashboard/incidents` | Incidentes críticos. |
| GET | `/api/admin/dashboard/modules-health` | Saúde de módulos. |
| POST | `/api/admin/exports/dashboard` | Solicitar exportação. |

### Eventos

- `admin.dashboard.viewed`
- `admin.dashboard.export_requested`
- `admin.incident.create_requested`

### Tabelas impactadas

- Leitura: `users`, `pj_profiles`, `rider_profiles`, `orders`, `transactions`, `module_catalog`, `observability_incidents`, `security_incidents`, `billing_invoices`.
- Escrita: `admin_action_audit` em exportação/ação crítica.

### Notificações

- Notificação interna para incidente crítico novo.
- Notificação para exportação pronta.

### Estados

- Loading com skeleton de cards e tabelas.
- Vazio: “Nenhum incidente crítico no período”.
- Erro: falha ao carregar KPIs com `trace_id`.

### Auditoria/compliance

- Exportação deve registrar filtros, quantidade estimada e finalidade.
- Dados pessoais devem ser agregados por padrão.

---

## A-03 — Usuários: Lista e Filtros

### Wireframe textual

```text
[Header: Usuários]
[Filtros: tipo | status conta | KYC | risco | região | documento | e-mail | telefone | data]
[Botão: Limpar filtros]
[Botão: Exportar]
[Tabela: nome | tipo | status | KYC | documento mascarado | e-mail | telefone | risco | último login | ações]
[Paginação]
```

### Campos

| Campo UI | Tipo | Origem | Destino |
|---|---|---|---|
| Tipo | enum | admin | filtro `users.user_kind` |
| Status conta | enum | admin | filtro `users.account_status` |
| KYC | enum | admin | filtro `users.kyc_status` |
| Risco | number/select | admin | filtro `users.risk_level` |
| Região | text/select | admin | filtro `users.ops_region_code` |
| Documento | text | admin | busca segura |
| E-mail | email | admin | busca lower(email) |
| Telefone | text | admin | busca E.164 |
| Data criação | date range | admin | filtro `created_at` |

### Validações frontend

- Documento aceita apenas caracteres permitidos e deve ser normalizado antes do envio.
- Telefone deve iniciar com `+` quando busca exata.
- Data final >= data inicial.

### Validações backend

- Aplicar máscara por permissão.
- Bloquear busca massiva sem filtro para perfis restritos.
- Rate limit para busca por documento/e-mail/telefone.

### Permissões

| Persona | Acesso |
|---|---|
| `ADMIN_SUPERADMIN` | leitura total e exportação |
| `ADMIN_OPERATOR` | leitura operacional e exportação se permitido |
| `ADMIN_ANALYST` | leitura mascarada |
| `ADMIN_VIEWER` | leitura mascarada e sem exportação |

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/users` | Listar usuários. |
| GET | `/api/admin/users/filters` | Opções de filtro. |
| POST | `/api/admin/exports/users` | Exportar usuários. |

### Eventos

- `admin.users.list_viewed`
- `admin.users.filtered`
- `admin.users.export_requested`

### Tabelas impactadas

- `users`
- `pj_profiles`
- `rider_profiles`
- `admin_action_audit` em exportação

### Notificações

- Nenhuma para consulta simples.
- Exportação pronta ou falha.

### Estados

- Loading tabela.
- Vazio: “Nenhum usuário encontrado com os filtros aplicados”.
- Erro: falha de consulta.

### Auditoria/compliance

- Busca por documento/e-mail/telefone deve ser auditável em perfis não superadmin.
- Exportação exige motivo.

---

## A-04 — Usuário: Detalhe Operacional

### Wireframe textual

```text
[Header: Nome | status | risco | ações]
[Tabs: Resumo | KYC/KYB | Wallets | Pedidos | Transações | Documentos | Incidentes | Auditoria | Permissões]
[Resumo: dados pessoais mascarados | tags | região | último login]
[Botões: Aprovar | Reprovar | Suspender | Bloquear | Reativar | Adicionar nota | Exportar histórico]
[Modal obrigatório: motivo da ação]
```

### Campos

| Campo UI | Tipo | Origem | Destino |
|---|---|---|---|
| Status conta | enum | admin | `users.account_status` |
| KYC | enum | admin/compliance | `users.kyc_status` |
| Risco | smallint | admin/motor risco | `users.risk_level` |
| Região | text | admin | `users.ops_region_code` |
| Tags internas | text[] | admin | `users.internal_tags` |
| Notas compliance | textarea | admin | `users.compliance_notes` |
| Motivo ação | textarea | admin | `admin_action_audit.reason` |

### Validações frontend

- Motivo obrigatório para bloqueio, suspensão, reprovação e exportação.
- Risco deve estar entre 0 e 5.
- UF deve ter 2 letras quando editável.

### Validações backend

- Transições de status permitidas.
- KYC aprovado exige dados mínimos completos.
- Admin não pode alterar a si próprio em ações críticas sem política especial.
- Registrar before/after JSON.

### Permissões

| Ação | Superadmin | Operator | Analyst | Viewer |
|---|---:|---:|---:|---:|
| Ver detalhe | sim | sim | sim mascarado | sim mascarado |
| Alterar status | sim | sim, se permitido | não | não |
| Alterar risco | sim | não, exceto permissão | não | não |
| Exportar | sim | sim, se permitido | sim, se permitido | não |
| Ver auditoria | sim | sim | sim parcial | não |

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/users/{user_id}` | Detalhe completo. |
| PATCH | `/api/admin/users/{user_id}/status` | Alterar status. |
| PATCH | `/api/admin/users/{user_id}/kyc` | Alterar KYC. |
| PATCH | `/api/admin/users/{user_id}/risk` | Alterar risco. |
| POST | `/api/admin/users/{user_id}/notes` | Adicionar nota. |
| GET | `/api/admin/users/{user_id}/audit` | Histórico. |

### Eventos

- `admin.user.viewed`
- `admin.user.status_changed`
- `admin.user.kyc_changed`
- `admin.user.risk_changed`
- `admin.user.note_added`

### Tabelas impactadas

- `users`
- `pj_profiles`
- `rider_profiles`
- `wallets`
- `orders`
- `transactions`
- `document_records`
- `security_incidents`
- `admin_action_audit`

### Notificações

- Usuário notificado quando conta for bloqueada/suspensa/reativada.
- Compliance notificado em risco alto.

### Estados

- Loading por aba.
- Vazio por aba: sem pedidos, sem transações, sem documentos.
- Erro: sem permissão, usuário não encontrado, conflito de atualização.

### Auditoria/compliance

- Toda ação mutável exige motivo.
- Documento, e-mail e telefone mascarados por padrão.
- Acesso a documentos sensíveis pode exigir break-glass.

---

## A-05 — Lojistas / PJ Admin

### Wireframe textual

```text
[Header: Lojistas]
[Filtros: CNPJ | razão social | KYB | status conta | plano | integração | data]
[Tabela: razão social | CNPJ mascarado | KYB | plano | produtos | pedidos | integrações | ações]
[Detalhe: Dados PJ | Billing | Produtos | Estoque | Integrações | Auditoria]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| CNPJ | text | admin/PJ | `pj_profiles.cnpj` |
| Razão social | text | PJ/Admin | `pj_profiles.legal_name` |
| Nome fantasia | text | PJ/Admin | `pj_profiles.trade_name` |
| Regime tributário | text | PJ/Admin | fiscal/ERP |
| KYB | enum | compliance | `pj_profiles.kyb_status` |
| Plano | text | billing | `billing_subscriptions.plan_code` |

### Validações frontend

- CNPJ deve ser normalizado para 14 dígitos.
- E-mail billing deve ter formato válido.
- Telefone billing deve seguir E.164.

### Validações backend

- CNPJ único.
- `user_kind` deve ser `PJ` para `pj_profiles`.
- KYB aprovado exige representante legal e CNPJ válido.

### Permissões

- Superadmin: total.
- Operator: aprovar/reprovar KYB se tiver permissão.
- Analyst: leitura e exportação controlada.
- Viewer: leitura mascarada.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/merchants` | Listar lojistas. |
| GET | `/api/admin/merchants/{user_id}` | Detalhar lojista. |
| PATCH | `/api/admin/merchants/{user_id}/kyb` | Atualizar KYB. |
| PATCH | `/api/admin/merchants/{user_id}/status` | Status conta PJ. |
| GET | `/api/admin/merchants/{user_id}/integrations` | Integrações. |

### Eventos

- `admin.merchant.viewed`
- `admin.merchant.kyb_changed`
- `admin.merchant.status_changed`

### Tabelas impactadas

- `users`
- `pj_profiles`
- `billing_customers`
- `billing_subscriptions`
- `inventory_items`
- `marketplace_listings`
- `orders`
- `admin_action_audit`

### Notificações

- Lojista notificado sobre aprovação/reprovação KYB.
- Operações notificadas em suspensão crítica.

### Estados

- Vazio: nenhum lojista encontrado.
- Erro: CNPJ inválido, sem permissão, conflito KYB.

### Auditoria/compliance

- Aprovação/reprovação KYB exige motivo e evidência.
- CNPJ e documentos devem ser mascarados em listas.

---

## A-06 — Entregadores Admin

### Wireframe textual

```text
[Header: Entregadores]
[Filtros: status rider | disponibilidade | zona | veículo | background check | score]
[Mapa por zona]
[Tabela: nome | status | disponibilidade | veículo | placa mascarada | zona | score | ações]
[Detalhe: documentos | entregas | incidentes | ganhos | auditoria]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Status rider | enum | admin | `rider_profiles.rider_status` |
| Disponibilidade | enum | app rider | `rider_profiles.availability_status` |
| Tipo veículo | text | rider | matching |
| Placa | text | rider | compliance |
| CNH | text | rider | compliance |
| Zona | text | admin/rider | dispatch |
| Background check | enum | compliance | liberação |
| Score | numeric | sistema | dispatch |

### Validações frontend

- Placa com 5 a 12 caracteres permitidos.
- Score de 0 a 100 quando editável por backoffice autorizado.

### Validações backend

- `user_kind = RIDER`.
- Não ativar rider sem background check aprovado quando política exigir.
- Suspensão de rider online deve forçar disponibilidade `OFFLINE`.

### Permissões

- Superadmin: total.
- Operator: aprovar/suspender se permitido.
- Analyst/Viewer: leitura.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/riders` | Listar riders. |
| GET | `/api/admin/riders/{user_id}` | Detalhar rider. |
| PATCH | `/api/admin/riders/{user_id}/status` | Alterar status. |
| PATCH | `/api/admin/riders/{user_id}/zone` | Alterar zona. |
| GET | `/api/admin/riders/{user_id}/shipments` | Entregas. |
| GET | `/api/admin/riders/{user_id}/incidents` | Incidentes. |

### Eventos

- `admin.rider.status_changed`
- `admin.rider.zone_changed`
- `admin.rider.background_check_changed`

### Tabelas impactadas

- `users`
- `rider_profiles`
- `delivery_shipments`
- `mobility_trips`
- `security_incidents`
- `admin_action_audit`

### Notificações

- Rider notificado sobre aprovação, suspensão, bloqueio ou alteração de zona.

### Estados

- Vazio: nenhum rider na zona/filtro.
- Erro: rider em entrega ativa não pode ser bloqueado sem fluxo de contingência.

### Auditoria/compliance

- Bloqueio/suspensão exige motivo.
- Documentos e CNH mascarados em lista.

---

## A-07 — Catálogo de Módulos

### Wireframe textual

```text
[Header: Módulos]
[Filtros: ativo | tier | data home | status | domínio]
[Tabela: número | código | nome | público | função | monetização | ativo | ações]
[Detalhe: descrição | regras | permissões | contratos | backlog | saúde]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Número | smallint | seed | `module_catalog.module_number` |
| Código | text | seed | `module_catalog.module_code` |
| Nome | text | seed/admin | UI |
| Público principal | text | seed | produto |
| Público secundário | text | seed | produto |
| Função central | text | seed | documentação |
| Monetização | text | seed | billing/produto |
| Ativo | boolean | admin | runtime |

### Validações frontend

- Código apenas maiúsculas, números e `_`.
- Número entre 1 e 99.

### Validações backend

- Código único.
- Número único.
- Não desativar módulo com dependências ativas sem confirmação.

### Permissões

- Superadmin: ativar/desativar.
- Operator: leitura e saúde.
- Analyst/Viewer: leitura.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/modules` | Listar módulos. |
| GET | `/api/admin/modules/{module_code}` | Detalhe. |
| PATCH | `/api/admin/modules/{module_code}` | Atualizar módulo. |
| GET | `/api/admin/modules/{module_code}/health` | Saúde. |

### Eventos

- `admin.module.viewed`
- `admin.module.status_changed`

### Tabelas impactadas

- `module_catalog`
- `module_delivery_registry`
- `business_rule_definitions`
- `admin_permissions`
- `domain_event_contracts`
- `admin_action_audit`

### Notificações

- Operações notificada em módulo desativado/bloqueado.

### Estados

- Vazio: nenhum módulo com filtro.
- Erro: dependência impede desativação.

### Auditoria/compliance

- Toda mudança de status de módulo exige motivo e before/after.

---

## A-08 — Regras de Negócio

### Wireframe textual

```text
[Header: Regras]
[Filtros: módulo | severidade | status | código]
[Tabela: código | módulo | nome | severidade | status | versão ativa | ações]
[Editor: constraints JSON | definition JSON | changelog]
[Botões: Criar | Dry-run | Enviar aprovação | Aprovar | Ativar | Desativar | Rollback]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Código regra | text | admin | `business_rule_definitions.rule_code` |
| Módulo | select | `module_catalog` | FK módulo |
| Nome | text | admin | regra |
| Descrição | textarea | admin | regra |
| Severidade | enum | admin | risco |
| Status | enum | workflow | regra |
| Constraints JSON | JSON | admin | runtime |
| Definition JSON | JSON | admin | versão |
| Change log | textarea | admin | auditoria |

### Validações frontend

- JSON válido.
- Código em formato `^[A-Z0-9_-]{3,80}$`.
- Change log obrigatório para nova versão.

### Validações backend

- Módulo existente.
- Aprovação exige admin com `can_approve`.
- Versão enabled exige `approved_by_admin_id` e `approved_at`.
- Não ativar duas versões incompatíveis quando regra for exclusiva.

### Permissões

| Ação | Superadmin | Operator | Analyst | Viewer |
|---|---:|---:|---:|---:|
| Ler | sim | sim | sim | sim |
| Criar/editar | sim | sim se `can_write` | não | não |
| Aprovar | sim | sim se `can_approve` | não | não |
| Dry-run | sim | sim | sim, se permitido | não |

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/rules` | Listar. |
| POST | `/api/admin/rules` | Criar regra. |
| POST | `/api/admin/rules/{rule_id}/versions` | Criar versão. |
| POST | `/api/admin/rules/{rule_id}/dry-run` | Testar. |
| POST | `/api/admin/rules/{rule_id}/approve` | Aprovar. |
| POST | `/api/admin/rules/{rule_id}/activate` | Ativar. |
| POST | `/api/admin/rules/{rule_id}/rollback` | Rollback. |

### Eventos

- `admin.rule.created`
- `admin.rule.version_created`
- `admin.rule.dry_run_executed`
- `admin.rule.approved`
- `admin.rule.activated`
- `admin.rule.rollback_executed`

### Tabelas impactadas

- `business_rule_definitions`
- `business_rule_versions`
- `business_rule_audit`
- `admin_action_audit`

### Notificações

- Aprovadores notificados em regra pendente.
- Operações notificada em regra crítica ativada.

### Estados

- Vazio: nenhuma regra.
- Erro: JSON inválido, sem aprovação, conflito de versão.

### Auditoria/compliance

- Toda alteração gera `business_rule_audit` append-only.
- Regras críticas exigem dupla aprovação quando política habilitada.

---

## A-09 — Billing Admin

### Wireframe textual

```text
[Header: Billing]
[Tabs: Clientes | Assinaturas | Faturas | Webhooks | Entitlements]
[Filtros: status | plano | ciclo | período | usuário | PJ]
[Tabelas específicas por aba]
[Botões: Sincronizar Stripe | Reprocessar webhook | Alterar plano | Exportar]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Billing customer | UUID | sistema | `billing_customers` |
| Stripe customer id | text | Stripe | cobrança |
| Plano | text | admin/produto | `billing_subscriptions.plan_code` |
| Status assinatura | enum text | Stripe/Admin | acesso |
| Ciclo | enum text | Admin/Stripe | cobrança |
| Fatura | UUID/text | Stripe | `billing_invoices` |
| Valor devido | decimal | Stripe | cobrança |
| Valor pago | decimal | Stripe | conciliação |
| Webhook event id | text | Stripe | idempotência |
| Processing status | enum text | sistema | fila webhook |

### Validações frontend

- Alteração de plano exige confirmação.
- Reprocessamento de webhook exige motivo.

### Validações backend

- Status de assinatura permitido.
- Moeda deve ser BRL.
- URLs de fatura devem iniciar com HTTP/HTTPS.
- Webhook Stripe id único.

### Permissões

- Superadmin: total.
- Operator financeiro: alterar plano/reprocessar.
- Analyst: leitura/exportação controlada.
- Viewer: leitura mascarada.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/billing/customers` | Clientes. |
| GET | `/api/admin/billing/subscriptions` | Assinaturas. |
| PATCH | `/api/admin/billing/subscriptions/{id}` | Alterar assinatura. |
| GET | `/api/admin/billing/invoices` | Faturas. |
| GET | `/api/admin/billing/webhooks` | Eventos. |
| POST | `/api/admin/billing/webhooks/{id}/reprocess` | Reprocessar. |
| GET | `/api/admin/billing/entitlements` | Entitlements. |
| PUT | `/api/admin/billing/entitlements/{plan_code}/{feature_key}` | Alterar entitlement. |

### Eventos

- `billing.customer.viewed`
- `billing.subscription.changed`
- `billing.invoice.viewed`
- `billing.webhook.reprocessed`
- `billing.entitlement.changed`

### Tabelas impactadas

- `billing_customers`
- `billing_subscriptions`
- `billing_invoices`
- `billing_webhook_events`
- `billing_plan_entitlements`
- `admin_action_audit`

### Notificações

- Lojista notificado em alteração de plano.
- Operações notificada em webhook falho recorrente.

### Estados

- Vazio por aba.
- Erro Stripe indisponível.
- Erro webhook já processado.

### Auditoria/compliance

- Alteração de plano, cancelamento e reprocessamento exigem motivo.
- Dados de cobrança mascarados para não autorizados.

---

## A-10 — Integrações Marketplace Admin

### Wireframe textual

```text
[Header: Integrações Marketplace]
[Cards provedores: Mercado Livre | Amazon | AliExpress | Alibaba | Magalu | CJ | Shopee]
[Detalhe provedor: credenciais | tokens | webhooks | sync | erros | logs]
[Botões: Conectar | Reautorizar | Testar credenciais | Testar webhook | Sincronizar catálogo | Sincronizar estoque | Pausar]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Provider | enum | admin | integração |
| Ambiente | enum | admin | sandbox/prod |
| Seller/store id | text | lojista/provedor | integração |
| Client id | text | provedor | auth |
| Secret reference | text | vault | auth |
| Token status | enum | sistema | saúde |
| Webhook URL | url | sistema | provedor |
| Webhook secret ref | text | vault | validação |
| Último sync catálogo | datetime | job | auditoria |
| Último erro | text | job | suporte |

### Validações frontend

- URL webhook válida.
- Secret nunca exibido; apenas referência.
- Produção exige confirmação.

### Validações backend

- Tokens criptografados ou guardados em vault.
- Scopes mínimos por provedor.
- Idempotência em sync.
- Rate limit por provedor.

### Permissões

- Superadmin: total.
- Operator integração: conectar/sync/testar.
- Analyst: leitura/logs mascarados.
- Viewer: leitura status.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/admin/integrations/marketplace` | Listar integrações. |
| POST | `/api/admin/integrations/marketplace/{provider}/connect` | Conectar. |
| POST | `/api/admin/integrations/marketplace/{provider}/reauthorize` | Reautorizar. |
| POST | `/api/admin/integrations/marketplace/{provider}/test` | Testar. |
| POST | `/api/admin/integrations/marketplace/{provider}/sync/catalog` | Sync catálogo. |
| POST | `/api/admin/integrations/marketplace/{provider}/sync/stock` | Sync estoque. |
| POST | `/api/admin/integrations/marketplace/{provider}/pause` | Pausar. |

### Eventos

- `integration.marketplace.connected`
- `integration.marketplace.reauthorized`
- `integration.marketplace.tested`
- `integration.marketplace.catalog_sync_requested`
- `integration.marketplace.stock_sync_requested`
- `integration.marketplace.paused`

### Tabelas impactadas

- `inventory_items`
- `inventory_lots`
- `marketplace_listings`
- `orders`
- `domain_event_contracts`
- `admin_action_audit`

### Notificações

- Lojista notificado em token expirado.
- Admin notificado em webhook falho.

### Estados

- Vazio: nenhuma integração conectada.
- Erro: credencial inválida, rate limit, provedor indisponível.

### Auditoria/compliance

- Nunca registrar segredo em log.
- Toda conexão/desconexão exige ator e motivo.

---

# 4. Lojista / Valley ERP

## E-01 — Home ERP

### Wireframe textual

```text
[Header ERP: loja ativa | busca | notificações | suporte]
[Cards: vendas hoje | pedidos pendentes | em preparo | enviados | estoque baixo | faturamento | saldo | integrações com erro]
[Filtros: loja | canal | período | status | categoria | armazém]
[Tabelas: pedidos recentes | produtos críticos | alertas de estoque | falhas de integração]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Loja ativa | select | `pj_profiles` | contexto ERP |
| Período | date range | lojista | métricas |
| Canal | select | integrações | métricas |
| Status pedido | multi-select | `orders.order_status` | filtro |
| Categoria | text/select | `inventory_items.category_path` | filtro |
| Armazém | select | `warehouses` | filtro |

### Validações frontend

- Data final >= data inicial.
- Usuário deve ter empresa selecionada quando possuir múltiplas.

### Validações backend

- `MERCHANT_*` só acessa dados do próprio `merchant_user_id`/empresa.
- Agregações devem respeitar plano/entitlement.

### Permissões

| Persona | Acesso |
|---|---|
| `MERCHANT_OWNER` | total na própria empresa |
| `MERCHANT_STAFF` | conforme permissão interna |
| `ADMIN_*` | via Admin/impersonation auditado |

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/home/summary` | KPIs ERP. |
| GET | `/api/erp/home/orders` | Pedidos recentes. |
| GET | `/api/erp/home/stock-alerts` | Alertas estoque. |
| GET | `/api/erp/home/integration-alerts` | Alertas integrações. |

### Eventos

- `erp.home.viewed`
- `erp.alert.opened`

### Tabelas impactadas

- `orders`
- `transactions`
- `inventory_items`
- `inventory_lots`
- `marketplace_listings`
- `warehouses`

### Notificações

- Estoque baixo.
- Novo pedido.
- Integração com erro.
- Fatura vencida.

### Estados

- Loading cards.
- Vazio: loja sem pedidos/produtos.
- Erro: sem empresa vinculada ou sem permissão.

### Auditoria/compliance

- Consulta simples sem auditoria individual.
- Exportação e impersonation admin devem auditar.

---

## E-02 — Cadastro da Empresa / Perfil PJ

### Wireframe textual

```text
[Tabs: Dados fiscais | Representante | Cobrança | Documentos | Status KYB]
[Form dados fiscais]
[Form representante]
[Form cobrança]
[Upload documentos]
[Botões: Salvar rascunho | Enviar para validação | Atualizar]
```

### Campos

| Campo | Tipo | Obrigatório | Destino |
|---|---|---:|---|
| Razão social | text | sim | `pj_profiles.legal_name` |
| Nome fantasia | text | não | `pj_profiles.trade_name` |
| CNPJ | text | sim | `pj_profiles.cnpj` |
| Inscrição estadual | text | não | `state_registration` |
| Inscrição municipal | text | não | `municipal_registration` |
| Regime tributário | text/select | não | `tax_regime` |
| CNAE principal | text | não | `cnae_primary` |
| CNAEs secundários | list text | não | `cnae_secondary` |
| Representante legal | text | sim | `legal_representative_name` |
| Documento representante | text | sim | `legal_representative_document` |
| E-mail cobrança | email | não | `billing_email` |
| Telefone cobrança | tel | não | `billing_phone` |
| Data abertura | date | não | `incorporation_date` |
| Documentos | file | condicional | `document_records` |

### Validações frontend

- CNPJ com 14 dígitos.
- E-mail válido.
- Telefone E.164.
- Nome legal não vazio.

### Validações backend

- `users.user_kind = PJ`.
- CNPJ único.
- KYB aprovado exige representante e documentos quando política exigir.

### Permissões

- `MERCHANT_OWNER`: editar enquanto não bloqueado.
- `MERCHANT_STAFF`: leitura ou edição se autorizado.
- `ADMIN_*`: via Admin, auditado.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/company` | Obter perfil PJ. |
| PATCH | `/api/erp/company` | Atualizar perfil PJ. |
| POST | `/api/erp/company/documents` | Enviar documento. |
| POST | `/api/erp/company/submit-kyb` | Enviar KYB. |

### Eventos

- `erp.company.updated`
- `erp.company.kyb_submitted`
- `erp.company.document_uploaded`

### Tabelas impactadas

- `users`
- `pj_profiles`
- `document_records`
- `billing_customers`

### Notificações

- Admin/compliance recebe KYB pendente.
- Lojista recebe resultado KYB.

### Estados

- Vazio: empresa ainda não cadastrada.
- Erro: CNPJ duplicado, documento inválido.

### Auditoria/compliance

- Alteração fiscal registra before/after.
- Documentos devem ter checksum SHA-256.

---

## E-03 — Produtos: Lista

### Wireframe textual

```text
[Header: Produtos]
[Busca: nome, SKU]
[Filtros: status | tipo | categoria | estoque | integração]
[Botões: Novo produto | Importar | Exportar]
[Tabela: SKU | nome | tipo | status | preço | custo | estoque | anúncios | ações]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Busca | text | lojista | filtro SKU/nome |
| Status | enum | lojista | `item_status` |
| Tipo | enum | lojista | `item_type` |
| Categoria | text[] | lojista | `category_path` |
| Estoque | select | sistema | filtro lotes |

### Validações frontend

- Busca mínima de 2 caracteres para consulta remota quando não paginado local.

### Validações backend

- Filtrar por `merchant_user_id` do lojista.
- Não retornar produtos de outro merchant.

### Permissões

- Owner: criar/editar/exportar.
- Staff: conforme permissão interna.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/products` | Listar produtos. |
| POST | `/api/erp/products/import` | Importar produtos. |
| POST | `/api/erp/products/export` | Exportar produtos. |

### Eventos

- `erp.products.list_viewed`
- `erp.products.import_requested`
- `erp.products.export_requested`

### Tabelas impactadas

- `inventory_items`
- `inventory_lots`
- `marketplace_listings`

### Notificações

- Importação concluída/falha.

### Estados

- Vazio: “Nenhum produto cadastrado”. CTA `Novo produto`.
- Erro: falha importação, sem permissão.

### Auditoria/compliance

- Exportação de catálogo deve ser registrada.

---

## E-04 — Produto: Detalhe e Edição

### Wireframe textual

```text
[Header: Produto | status | ações]
[Tabs: Dados | Preço | Estoque | Anúncios | Fiscal | Histórico]
[Form produto]
[Botões: Salvar | Publicar anúncio | Pausar | Arquivar | Duplicar]
```

### Campos

| Campo | Tipo | Obrigatório | Destino |
|---|---|---:|---|
| SKU interno | text | sim | `inventory_items.item_sku` |
| SKU externo | text | não | `external_sku` |
| Nome | text | sim | `item_name` |
| Descrição | textarea | não | `item_description` |
| Tipo | enum | sim | `item_type` |
| Status | enum | sim | `item_status` |
| Categoria | tag list | não | `category_path` |
| Unidade | text/select | sim | `unit_of_measure` |
| Preço base | decimal | sim | `base_price_brl` |
| Custo referência | decimal | sim | `cost_reference_brl` |
| Classe fiscal | text | não | `tax_class` |
| Atributos | JSON/form dinâmico | não | `attributes_json` |

### Validações frontend

- SKU não vazio.
- Nome não vazio.
- Preço e custo >= 0.
- JSON de atributos válido.

### Validações backend

- SKU único por merchant.
- `merchant_user_id` obrigatório.
- Produto arquivado não pode ser publicado sem reativação.

### Permissões

- Owner: total.
- Staff catálogo: criar/editar.
- Staff atendimento: leitura.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/products/{item_id}` | Detalhe. |
| POST | `/api/erp/products` | Criar. |
| PATCH | `/api/erp/products/{item_id}` | Atualizar. |
| POST | `/api/erp/products/{item_id}/archive` | Arquivar. |
| POST | `/api/erp/products/{item_id}/duplicate` | Duplicar. |

### Eventos

- `erp.product.created`
- `erp.product.updated`
- `erp.product.archived`
- `erp.product.duplicated`

### Tabelas impactadas

- `inventory_items`
- `marketplace_listings`
- `inventory_movements` quando alteração gerar ajuste operacional

### Notificações

- Nenhuma por padrão; integração pode receber atualização de catálogo.

### Estados

- Loading detalhe.
- Erro: SKU duplicado, produto não encontrado, sem permissão.

### Auditoria/compliance

- Alteração de preço/custo deve auditar before/after.

---

## E-05 — Estoque, Lotes e WMS

### Wireframe textual

```text
[Header: Estoque]
[Tabs: Lotes | Movimentos | Armazéns | Contagem cíclica]
[Filtros: produto | armazém | status lote | fornecedor | validade]
[Botões: Receber estoque | Ajustar | Transferir | Contar | Exportar]
[Tabelas por aba]
```

### Campos principais

| Campo | Tipo | Destino |
|---|---|---|
| Armazém | select | `inventory_lots.warehouse_id` |
| Produto | select | `inventory_lots.item_id` |
| Fornecedor | select | `inventory_lots.supplier_id` |
| Código lote | text | `lot_code` |
| Status lote | enum | `lot_status` |
| Quantidade disponível | decimal | `quantity_available` |
| Quantidade reservada | decimal | `quantity_reserved` |
| Quantidade avariada | decimal | `quantity_damaged` |
| Custo unitário | decimal | `unit_cost_brl` |
| Validade | datetime | `expires_at` |
| Motivo movimento | text | `inventory_movements.movement_reason` |

### Validações frontend

- Quantidades não negativas.
- Movimento não pode ter quantidade zero.
- Motivo obrigatório para ajuste manual.

### Validações backend

- Item deve pertencer ao merchant.
- Lote único por produto/armazém/código.
- Movimento append-only.
- Não permitir reserva maior que disponibilidade.

### Permissões

- Owner: total.
- Staff estoque: operar estoque.
- Staff atendimento: leitura.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/stock/lots` | Listar lotes. |
| POST | `/api/erp/stock/receive` | Receber estoque. |
| POST | `/api/erp/stock/adjust` | Ajuste manual. |
| POST | `/api/erp/stock/transfer` | Transferir. |
| GET | `/api/erp/stock/movements` | Movimentos. |
| POST | `/api/erp/wms/cycle-counts` | Contagem. |

### Eventos

- `erp.stock.received`
- `erp.stock.adjusted`
- `erp.stock.reserved`
- `erp.stock.released`
- `erp.stock.transferred`
- `erp.wms.cycle_count_recorded`

### Tabelas impactadas

- `warehouses`
- `inventory_lots`
- `inventory_movements`
- `warehouse_cycle_counts`

### Notificações

- Estoque baixo.
- Divergência de contagem.
- Lote vencendo.

### Estados

- Vazio: sem lotes/armazéns.
- Erro: saldo insuficiente, lote duplicado, armazém inativo.

### Auditoria/compliance

- Ajuste manual exige motivo e ator.
- Movimentos não podem ser editados/deletados.

---

## E-06 — Anúncios Marketplace

### Wireframe textual

```text
[Header: Marketplace]
[Filtros: status | canal | produto | estratégia estoque]
[Botão: Novo anúncio]
[Tabela: título | produto | preço | comissão | estoque snapshot | status | publicado em | ações]
[Form anúncio]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Produto | select | `marketplace_listings.item_id` |
| Wallet recebimento | select | `wallet_id` |
| Título | text | `listing_title` |
| Descrição | textarea | `listing_description` |
| Preço | decimal | `price_brl` |
| Comissão | decimal | `commission_rate` |
| Estratégia estoque | enum text | `stock_strategy` |
| Quantidade snapshot | decimal | `available_quantity_snapshot` |
| Status | enum | `listing_status` |

### Validações frontend

- Preço >= 0.
- Comissão entre 0 e 1.
- Título obrigatório.
- Produto ativo recomendado para publicação.

### Validações backend

- Wallet pertence ao merchant.
- Produto pertence ao merchant.
- Anúncio ativo exige `published_at`.
- Um anúncio por item/merchant.

### Permissões

- Owner: total.
- Staff catálogo/marketplace: criar/editar/publicar se permitido.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/listings` | Listar. |
| POST | `/api/erp/listings` | Criar. |
| PATCH | `/api/erp/listings/{listing_id}` | Editar. |
| POST | `/api/erp/listings/{listing_id}/publish` | Publicar. |
| POST | `/api/erp/listings/{listing_id}/pause` | Pausar. |
| POST | `/api/erp/listings/{listing_id}/sync` | Sincronizar canais. |

### Eventos

- `marketplace.listing.created`
- `marketplace.listing.published`
- `marketplace.listing.paused`
- `marketplace.listing.synced`

### Tabelas impactadas

- `marketplace_listings`
- `inventory_items`
- `inventory_lots`
- `wallets`

### Notificações

- Lojista recebe erro de sync.
- Usuário pode receber alerta de produto favorito disponível.

### Estados

- Vazio: nenhum anúncio.
- Erro: produto sem estoque, wallet inválida, integração indisponível.

### Auditoria/compliance

- Alteração de preço e comissão deve auditar before/after.

---

## E-07 — Pedidos ERP

### Wireframe textual

```text
[Header: Pedidos]
[Filtros: status | domínio | canal | período | pagamento | entregador]
[Tabela: pedido | cliente | status | total | pagamento | entrega | criado em | ações]
[Botões: Confirmar | Preparar | Despachar | Cancelar | Reembolsar]
```

### Campos

| Campo | Tipo | Origem/Destino |
|---|---|---|
| Status | enum | `orders.order_status` |
| Domínio | enum | `orders.order_domain` |
| Cliente | UUID/display | `orders.user_id` |
| Merchant | UUID | `orders.merchant_user_id` |
| Entregador | UUID | `orders.rider_user_id` |
| Total | decimal | `orders.total_brl` |
| Tracking | text | `tracking_code`, `tracking_provider` |

### Validações frontend

- Cancelamento exige motivo.
- Reembolso exige confirmação e permissão.

### Validações backend

- Transição de status válida.
- Pedido deve pertencer ao merchant.
- Reembolso exige transação elegível.

### Permissões

- Owner: total.
- Staff atendimento: confirmar/cancelar se permitido.
- Staff cozinha/fulfillment: preparar/despachar.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/orders` | Listar pedidos. |
| GET | `/api/erp/orders/{order_id}` | Detalhe. |
| POST | `/api/erp/orders/{order_id}/confirm` | Confirmar. |
| POST | `/api/erp/orders/{order_id}/prepare` | Preparar. |
| POST | `/api/erp/orders/{order_id}/dispatch` | Despachar. |
| POST | `/api/erp/orders/{order_id}/cancel` | Cancelar. |
| POST | `/api/erp/orders/{order_id}/refund` | Reembolsar. |

### Eventos

- `erp.order.confirmed`
- `erp.order.preparation_started`
- `erp.order.dispatched`
- `erp.order.cancelled`
- `erp.order.refund_requested`

### Tabelas impactadas

- `orders`
- `transactions`
- `delivery_shipments`
- `inventory_movements`
- `document_records`

### Notificações

- Usuário notificado em cada mudança de status.
- Rider notificado quando delivery for solicitado.

### Estados

- Vazio: sem pedidos.
- Erro: status inválido, pagamento não autorizado, estoque insuficiente.

### Auditoria/compliance

- Cancelamento/reembolso exigem motivo.
- Alteração manual de status deve auditar.

---

## E-08 — Compras e Reposição

### Wireframe textual

```text
[Header: Compras]
[Filtros: fornecedor | status | armazém | período]
[Tabela: ordem | fornecedor | status | total esperado | previsão | recebido | ações]
[Detalhe: itens | aprovações | recebimento | documentos]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Fornecedor | select | `procurement_orders.supplier_id` |
| Armazém destino | select | `destination_warehouse_id` |
| Wallet | select | `wallet_id` |
| Status | enum | `procurement_status` |
| Total esperado | decimal | `expected_total_brl` |
| Referência externa | text | `external_reference` |
| Itens | list | `procurement_order_items` |

### Validações frontend

- Ordem deve ter pelo menos um item para envio.
- Quantidade pedida > 0.
- Preço unitário >= 0.

### Validações backend

- Fornecedor ativo.
- Armazém ativo.
- Item pertence ao comprador.
- Quantidade recebida <= quantidade pedida.

### Permissões

- Owner: total.
- Staff compras: criar/receber.
- Staff estoque: receber se permitido.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/erp/procurements` | Listar. |
| POST | `/api/erp/procurements` | Criar. |
| PATCH | `/api/erp/procurements/{id}` | Atualizar. |
| POST | `/api/erp/procurements/{id}/approve` | Aprovar. |
| POST | `/api/erp/procurements/{id}/receive` | Receber. |
| POST | `/api/erp/procurements/{id}/cancel` | Cancelar. |

### Eventos

- `erp.procurement.created`
- `erp.procurement.approved`
- `erp.procurement.placed`
- `erp.procurement.received`
- `erp.procurement.cancelled`

### Tabelas impactadas

- `procurement_orders`
- `procurement_order_items`
- `inventory_lots`
- `inventory_movements`
- `wallets`

### Notificações

- Aprovador notificado.
- Estoque notificado em entrega prevista.

### Estados

- Vazio: nenhuma compra.
- Erro: fornecedor suspenso, item inválido, divergência recebimento.

### Auditoria/compliance

- Aprovação, recebimento e cancelamento exigem ator e motivo quando divergente.

---

# 5. Usuário / APK Android

## U-01 — Onboarding Usuário

### Wireframe textual

```text
[Passo 1: Dados pessoais]
[Passo 2: Documento]
[Passo 3: Contato]
[Passo 4: Termos e privacidade]
[Passo 5: PIN/biometria opcional]
[Botões: Voltar | Continuar | Finalizar]
```

### Campos

| Campo | Tipo | Obrigatório | Destino |
|---|---|---:|---|
| Nome completo | text | sim | `users.full_name` |
| Nome de exibição | text | não | `users.display_name` |
| E-mail | email | condicional | `users.email` |
| Telefone | tel | sim | `users.phone_e164` |
| Data nascimento | date | sim | `users.birth_date` |
| Cidade nascimento | text | não | `birth_city` |
| UF nascimento | text | não | `birth_state` |
| País documento | text | sim | `document_country` |
| Tipo documento | text | sim | `document_type` |
| Número documento | text | sim | `document_number` |
| Aceite termos | checkbox | sim | `terms_accepted_at` |
| Aceite privacidade | checkbox | sim | `privacy_accepted_at` |
| Biometria | opt-in | não | `security_biometric_credentials` |

### Validações frontend

- Nome não vazio.
- Telefone E.164.
- E-mail válido quando informado.
- Termos e privacidade obrigatórios.
- UF com 2 letras quando preenchida.

### Validações backend

- Documento único por país/tipo/número.
- E-mail único quando informado.
- Telefone único quando informado.
- Criar wallet inicial conforme política.

### Permissões

- Público não autenticado.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/app/auth/register` | Criar usuário. |
| POST | `/api/app/auth/otp/send` | Enviar OTP. |
| POST | `/api/app/auth/otp/verify` | Verificar telefone/e-mail. |
| POST | `/api/app/security/biometrics/enroll` | Cadastrar biometria. |

### Eventos

- `user.registration_started`
- `user.created`
- `user.terms_accepted`
- `user.privacy_accepted`
- `user.biometric_enrolled`

### Tabelas impactadas

- `users`
- `wallets`
- `security_biometric_credentials`
- `document_records`

### Notificações

- OTP.
- Boas-vindas.

### Estados

- Loading ao validar documento/OTP.
- Erro: documento duplicado, telefone inválido, OTP inválido.

### Auditoria/compliance

- Registrar consentimentos com timestamp.
- Não armazenar biometria bruta.

---

## U-02 — Home Usuário

### Wireframe textual

```text
[Header: saudação | notificações | perfil]
[Busca global]
[Atalhos: Marketplace | Food | Mobilidade | Wallet | Pedidos | Helena | Segurança]
[Card wallet]
[Card pedido em andamento]
[Card recomendações]
[Banner campanha]
[Lista: recentes/favoritos]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Busca | text | usuário | navegação/pesquisa |
| Atalho módulo | button | módulo ativo | rota app |
| Notificação | list | backend | centro notificações |

### Validações frontend

- Busca remota apenas acima de 2 caracteres.
- Módulo desativado deve exibir mensagem amigável.

### Validações backend

- Retornar somente módulos ativos/permitidos.
- Personalização deve respeitar consentimento.

### Permissões

- `USER_PF` autenticado.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/app/home` | Home consolidada. |
| GET | `/api/app/modules` | Módulos ativos. |
| GET | `/api/app/notifications` | Notificações. |
| GET | `/api/app/search` | Busca global. |

### Eventos

- `app.home.viewed`
- `app.module_shortcut_clicked`
- `app.search_submitted`

### Tabelas impactadas

- Leitura: `users`, `wallets`, `orders`, `marketplace_listings`, `gamification_campaigns`, `points_ledger`.

### Notificações

- Pedidos, wallet, segurança, Helena.

### Estados

- Loading com cards skeleton.
- Vazio: usuário novo sem histórico.
- Erro: offline ou falha home.

### Auditoria/compliance

- Busca sensível não deve vazar dados de outros usuários.

---

## U-03 — Marketplace Lista

### Wireframe textual

```text
[Header: Marketplace]
[Busca]
[Categorias horizontais]
[Filtros: preço | categoria | lojista | entrega | disponibilidade]
[Ordenação]
[Grid/lista produtos]
[Card: imagem | título | preço | loja | prazo | estoque | favorito]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Busca | text | usuário | query listings |
| Categoria | select | `category_path` | filtro |
| Preço mínimo/máximo | decimal | usuário | filtro |
| Lojista | select | merchants | filtro |
| Disponibilidade | select | estoque | filtro |
| Ordenação | enum | usuário | query |

### Validações frontend

- Preço mínimo <= preço máximo.
- Busca sanitizada.

### Validações backend

- Listar apenas `listing_status = ACTIVE`.
- Não expor custo do produto.
- Considerar estoque conforme `stock_strategy`.

### Permissões

- Usuário autenticado ou visitante se política permitir vitrine pública.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/app/marketplace/listings` | Listar anúncios. |
| GET | `/api/app/marketplace/categories` | Categorias. |
| POST | `/api/app/favorites/{listing_id}` | Favoritar. |

### Eventos

- `marketplace.list_viewed`
- `marketplace.search_submitted`
- `marketplace.listing_favorited`

### Tabelas impactadas

- `marketplace_listings`
- `inventory_items`
- `inventory_lots`

### Notificações

- Produto favorito disponível/queda de preço se feature habilitada.

### Estados

- Vazio: nenhum produto encontrado.
- Erro: falha de busca.

### Auditoria/compliance

- Sem auditoria individual exceto abuso/fraude.

---

## U-04 — Produto Detalhe e Carrinho

### Wireframe textual

```text
[Galeria imagens]
[Título | loja | preço | prazo]
[Descrição]
[Variações]
[Quantidade]
[Frete estimado]
[Botões: Adicionar ao carrinho | Comprar agora | Favoritar]
[Seções: detalhes | avaliações | política]
```

### Campos

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| Listing | UUID | rota | detalhe |
| Quantidade | decimal/int | usuário | carrinho |
| Variação | select | attributes | carrinho |
| CEP/endereço | text | usuário | frete |

### Validações frontend

- Quantidade > 0.
- Quantidade não maior que disponibilidade exibida quando real-time.

### Validações backend

- Listing ativo.
- Produto não arquivado.
- Estoque suficiente ou estratégia permite preorder/dropship.

### Permissões

- `USER_PF`.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/app/marketplace/listings/{listing_id}` | Detalhe. |
| POST | `/api/app/cart/items` | Adicionar ao carrinho. |
| POST | `/api/app/checkout/quote` | Cotar frete/total. |

### Eventos

- `marketplace.product_viewed`
- `cart.item_added`
- `checkout.quote_requested`

### Tabelas impactadas

- `marketplace_listings`
- `inventory_items`
- `inventory_lots`
- carrinho runtime/cache quando existir

### Notificações

- Nenhuma imediata.

### Estados

- Vazio/erro: produto indisponível.
- Loading: cotação de frete.

### Auditoria/compliance

- Não exibir custo/margem.

---

## U-05 — Checkout

### Wireframe textual

```text
[Endereço entrega]
[Itens]
[Forma pagamento/wallet]
[Cupons]
[Observações]
[Resumo: subtotal | frete | taxa | desconto | imposto | total]
[Checkbox consentimento pagamento]
[Botão: Confirmar pedido]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Endereço entrega | JSON form | `orders.dropoff_address_json` |
| Wallet | select | `orders.wallet_id` |
| Cupom | text | cálculo desconto |
| Observação | textarea | `orders.customer_notes` |
| Agendamento | datetime | `orders.scheduled_for` |
| Consentimento pagamento | checkbox/biometria | auditoria |

### Validações frontend

- Endereço obrigatório.
- Wallet obrigatória.
- Total deve ser mostrado antes da confirmação.
- Consentimento obrigatório.

### Validações backend

- Wallet pertence ao usuário.
- Total consistente.
- Valores não negativos.
- Estoque disponível/reservável.
- Criar transação idempotente.

### Permissões

- `USER_PF` autenticado e ativo.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/app/checkout/quote` | Cotar. |
| POST | `/api/app/orders` | Criar pedido. |
| POST | `/api/app/payments/authorize` | Autorizar pagamento. |

### Eventos

- `checkout.started`
- `checkout.quote_calculated`
- `order.placed`
- `payment.authorized`
- `payment.failed`

### Tabelas impactadas

- `orders`
- `transactions`
- `wallets`
- `inventory_movements`
- `delivery_shipments` quando entrega aplicável

### Notificações

- Usuário: pedido criado/pagamento aprovado.
- Lojista: novo pedido.

### Estados

- Loading cotação/pagamento.
- Erro: saldo insuficiente, estoque insuficiente, pagamento falhou.

### Auditoria/compliance

- Pagamento exige consentimento rastreável.
- Não registrar dados sensíveis de pagamento bruto.

---

## U-06 — Pedidos Usuário

### Wireframe textual

```text
[Tabs: Em andamento | Entregues | Cancelados | Reembolsos | Disputas]
[Card pedido: status | loja | total | data | ETA]
[Detalhe: timeline | mapa | itens | pagamento | documentos | ajuda | avaliação]
```

### Campos

| Campo | Tipo | Origem |
|---|---|---|
| Status | enum | `orders.order_status` |
| Timeline | events | `delivery_shipment_events` / order timestamps |
| Mapa | geo | shipment/trip |
| Documentos | list | `document_records` |
| Avaliação | form | módulo avaliações futuro |

### Validações frontend

- Cancelamento exige motivo quando permitido.
- Avaliação exige nota válida.

### Validações backend

- Usuário só acessa seus pedidos.
- Cancelamento somente em status permitido.
- Documento pertence ao pedido/usuário.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/app/orders` | Listar pedidos. |
| GET | `/api/app/orders/{order_id}` | Detalhe. |
| POST | `/api/app/orders/{order_id}/cancel` | Cancelar. |
| POST | `/api/app/orders/{order_id}/support` | Abrir suporte. |
| POST | `/api/app/orders/{order_id}/rating` | Avaliar. |

### Eventos

- `app.orders.viewed`
- `order.cancel_requested`
- `order.support_requested`
- `order.rated`

### Tabelas impactadas

- `orders`
- `delivery_shipments`
- `delivery_shipment_events`
- `transactions`
- `document_records`
- `security_incidents` se suporte de risco

### Notificações

- Atualizações de status em push.

### Estados

- Vazio: nenhum pedido.
- Erro: pedido não encontrado, sem permissão.

### Auditoria/compliance

- Cancelamento e suporte sensível exigem motivo.

---

## U-07 — Wallet Usuário

### Wireframe textual

```text
[Header Wallet]
[Saldo BRL | saldo NEX]
[Disponível | bloqueado | pendente]
[Limites]
[Cartão LED/NFC]
[Extrato]
[Botões: Adicionar saldo | Transferir | Sacar | Ver limites]
```

### Campos

| Campo | Tipo | Origem |
|---|---|---|
| Saldo BRL/NEX | decimal | `wallets` |
| Limites | decimal | `wallets` |
| Extrato | list | `transactions` |
| Cartão LED | object | `led_cards` |

### Validações frontend

- Transferência exige valor > 0.
- Valor não pode exceder saldo disponível.

### Validações backend

- Wallet ativa.
- Limites diários/mensais.
- Transação append-only.
- Contraparte válida.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/app/wallets` | Wallets. |
| GET | `/api/app/wallets/{wallet_id}/transactions` | Extrato. |
| POST | `/api/app/wallets/{wallet_id}/transfer` | Transferir. |
| GET | `/api/app/led-cards` | Cartões. |

### Eventos

- `wallet.viewed`
- `wallet.transfer_requested`
- `wallet.transfer_completed`
- `wallet.transfer_failed`

### Tabelas impactadas

- `wallets`
- `transactions`
- `led_cards`

### Notificações

- Transferência concluída/falha.
- Wallet congelada/bloqueada.

### Estados

- Vazio: sem transações.
- Erro: wallet bloqueada, saldo insuficiente.

### Auditoria/compliance

- Operações financeiras exigem autenticação forte quando política exigir.

---

## U-08 — Helena / Chat / Agenda / Advisor

### Wireframe textual

```text
[Header Helena: persona pessoal/profissional]
[Chat: mensagens]
[Input texto | botão microfone | anexos permitidos]
[Cards sugeridos: criar lembrete | salvar memória | recomendação]
[Tabs: Chat | Agenda | Memórias | Advisor | Consentimentos]
[Modal consentimento: escopo | motivo | duração | confirmar]
```

### Campos

| Campo | Tipo | Origem/Destino |
|---|---|---|
| Mensagem | text/audio | chat runtime / `chat_messages` |
| Persona | enum | contexto |
| Consent scope | enum | `ai_memory.consent_scope` lógico |
| Item agenda | object | `agenda_items` Mongo |
| Memória | object | `ai_memory` Mongo |
| Insight | object | `advisor_insights` |
| Consentimento | object | auditoria/evento |

### Validações frontend

- Mensagem não vazia.
- Microfone exige permissão do dispositivo.
- Ação sensível exige consentimento explícito.

### Validações backend

- Não cruzar persona pessoal/profissional sem consentimento.
- Advisor não executa ação financeira/saúde/mobilidade sem consentimento.
- Retention conforme classe do dado.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/app/helena/chat/messages` | Enviar mensagem. |
| GET | `/api/app/helena/conversations` | Conversas. |
| POST | `/api/app/helena/agenda/items` | Criar agenda. |
| GET | `/api/app/helena/memory` | Memórias. |
| POST | `/api/app/helena/memory/promote` | Promover contexto. |
| POST | `/api/app/helena/advisor/insights/{id}/consent` | Consentir ação. |

### Eventos

- `chat.conversation.opened`
- `chat.message.persisted`
- `chat.context.promoted`
- `agenda.item.created`
- `agenda.reminder.triggered`
- `advisor.insight.generated`
- `advisor.action.proposed`
- `advisor.consent.recorded`

### Tabelas/collections impactadas

- `chat_conversations`
- `chat_messages`
- `advisor_insights`
- `financial_goals`
- Mongo `ai_memory`
- Mongo `agenda_items`
- `admin_action_audit` apenas em acesso admin/break-glass

### Notificações

- Lembrete de agenda.
- Consentimento pendente.
- Insight relevante.

### Estados

- Loading resposta Helena.
- Vazio: sem conversas/memórias/agenda.
- Erro: microfone indisponível, consentimento necessário, IA indisponível.

### Auditoria/compliance

- Promover memória exige escopo.
- Acesso admin a conversa/memória exige break-glass.
- Preferir resumo governado a texto bruto persistente.

---

## U-09 — Segurança Usuário

### Wireframe textual

```text
[Header Segurança]
[Botão SOS destacado]
[Cards: contatos confiáveis | biometria | incidentes | rota compartilhada]
[Lista contatos]
[Lista incidentes]
[Botões: Adicionar contato | Cadastrar biometria | Reportar incidente]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Nome contato | text | `security_trusted_contacts.contact_name` |
| Relação | text | `relation_label` |
| Telefone | tel | `phone_e164` |
| E-mail | email | `email` |
| Prioridade | smallint | `priority` |
| Notificar SMS/e-mail/push | boolean | flags |
| Tipo incidente | enum | `security_incidents.incident_type` |
| Severidade | enum | `severity` |
| Evidência | file | `document_records` |

### Validações frontend

- Contato precisa ter telefone, e-mail ou push.
- Prioridade 1 a 10.
- SOS pede confirmação curta ou gesto rápido conforme UX.

### Validações backend

- Usuário só gerencia próprios contatos.
- Incidente deve ter âncora: pedido, trip, shipment, geo ou correlation id.
- Evidência com checksum.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/app/security/contacts` | Listar contatos. |
| POST | `/api/app/security/contacts` | Criar contato. |
| PATCH | `/api/app/security/contacts/{id}` | Atualizar. |
| POST | `/api/app/security/sos` | Acionar SOS. |
| GET | `/api/app/security/incidents` | Incidentes. |
| POST | `/api/app/security/incidents/{id}/evidence` | Anexar evidência. |

### Eventos

- `security.contact.created`
- `security.sos.created`
- `security.incident.created`
- `security.evidence_attached`
- `security.contact_notified`

### Tabelas impactadas

- `security_trusted_contacts`
- `security_incidents`
- `security_incident_events`
- `document_records`

### Notificações

- Contatos confiáveis notificados em SOS.
- Admin/operação notificado em incidente crítico.

### Estados

- Vazio: nenhum contato/incident.
- Erro: sem localização, falha notificação, contato inválido.

### Auditoria/compliance

- SOS e incidentes são trilha crítica.
- Evidências não podem ser apagadas sem correção auditada.

---

# 6. Entregador / APK Android

## R-01 — Onboarding Rider

### Wireframe textual

```text
[Passo 1: dados pessoais]
[Passo 2: veículo]
[Passo 3: CNH/documentos]
[Passo 4: zona de atendimento]
[Passo 5: seguro e aceite]
[Status: aguardando análise | aprovado | rejeitado]
```

### Campos

| Campo | Tipo | Obrigatório | Destino |
|---|---|---:|---|
| Nome | text | sim | `users.full_name` |
| Documento | text | sim | `users.document_number` |
| Telefone | tel | sim | `users.phone_e164` |
| Tipo veículo | text/select | sim | `rider_profiles.vehicle_type` |
| Placa | text | condicional | `vehicle_plate` |
| Modelo | text | não | `vehicle_model` |
| CNH | text | condicional | `driver_license_number` |
| Categoria CNH | text | condicional | `driver_license_category` |
| Validade CNH | date | condicional | `driver_license_expires_at` |
| Zona | text/select | sim | `service_zone_code` |
| Seguro | text/file | não | `insurance_policy_ref` / docs |
| Documentos | file | sim | `document_records` |

### Validações frontend

- Telefone E.164.
- Placa no padrão permitido.
- Validade CNH futura quando obrigatória.

### Validações backend

- Criar `users.user_kind = RIDER`.
- `rider_profiles` só aceita usuário RIDER.
- Background check antes de ativar.

### Permissões

- Público/autenticado em onboarding.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/rider/onboarding/start` | Iniciar. |
| PATCH | `/api/rider/profile` | Atualizar dados. |
| POST | `/api/rider/documents` | Enviar docs. |
| POST | `/api/rider/onboarding/submit` | Enviar análise. |
| GET | `/api/rider/onboarding/status` | Status. |

### Eventos

- `rider.onboarding_started`
- `rider.document_uploaded`
- `rider.onboarding_submitted`
- `rider.background_check_requested`

### Tabelas impactadas

- `users`
- `rider_profiles`
- `document_records`
- `security_biometric_credentials`

### Notificações

- Rider recebe status de análise.
- Admin recebe fila pendente.

### Estados

- Vazio: onboarding não iniciado.
- Erro: documento inválido, placa inválida, upload falhou.

### Auditoria/compliance

- Documentos com checksum.
- Reprovação exige motivo.

---

## R-02 — Home e Disponibilidade Rider

### Wireframe textual

```text
[Header: status | zona | score]
[Toggle: Offline/Online]
[Botões: Pausar | Encerrar turno | SOS]
[Cards: ganhos hoje | entregas concluídas | score | alertas]
[Lista: próximas ações/ofertas]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Disponibilidade | enum | `rider_profiles.availability_status` |
| Zona | text | `service_zone_code` |
| Status rider | enum | `rider_status` |
| Localização atual | geo | dispatch runtime/eventos |

### Validações frontend

- Para ficar online, localização deve estar habilitada.
- Não permitir online se onboarding pendente.

### Validações backend

- Rider ativo.
- Background check aprovado.
- Sem bloqueio/suspensão.
- Disponibilidade permitida: `OFFLINE`, `ONLINE`, `BUSY`, `PAUSED`.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/rider/home` | Home. |
| PATCH | `/api/rider/availability` | Alterar disponibilidade. |
| POST | `/api/rider/location/ping` | Atualizar localização. |

### Eventos

- `rider.availability_changed`
- `rider.location_pinged`
- `rider.shift_started`
- `rider.shift_paused`
- `rider.shift_ended`

### Tabelas impactadas

- `rider_profiles`
- eventos runtime/logs de localização
- `security_incidents` se SOS

### Notificações

- Alertas operacionais.
- Suspensão/bloqueio.

### Estados

- Vazio: sem ofertas.
- Erro: localização negada, rider suspenso.

### Auditoria/compliance

- Mudanças de disponibilidade registradas.
- Localização usada apenas durante operação/consentimento.

---

## R-03 — Oferta de Entrega/Corrida

### Wireframe textual

```text
[Modal/card oferta]
[Tipo: entrega/corrida]
[Origem | destino]
[Distância | tempo estimado | valor]
[Pacotes/peso ou passageiros]
[Timer regressivo]
[Botões: Aceitar | Recusar]
```

### Campos

| Campo | Tipo | Origem |
|---|---|---|
| Shipment/trip id | UUID | dispatch |
| Tipo serviço | enum | `delivery_shipments.shipment_kind` / `mobility_trips.trip_service` |
| Origem | JSON | pickup |
| Destino | JSON | dropoff |
| Distância | decimal | rota |
| Duração | integer | rota |
| Valor | decimal | cálculo |
| Timer | integer | dispatch |

### Validações frontend

- Aceitar apenas uma vez.
- Bloquear aceite após expiração.

### Validações backend

- Rider deve estar `ONLINE`.
- Oferta ainda disponível.
- Não aceitar duas tarefas conflitantes.
- Alterar rider para `BUSY` quando aceito.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/rider/offers/active` | Oferta atual. |
| POST | `/api/rider/offers/{offer_id}/accept` | Aceitar. |
| POST | `/api/rider/offers/{offer_id}/reject` | Recusar. |

### Eventos

- `dispatch.offer_created`
- `dispatch.offer_accepted`
- `dispatch.offer_rejected`
- `dispatch.offer_expired`

### Tabelas impactadas

- `delivery_shipments`
- `mobility_trips`
- `rider_profiles`
- `delivery_shipment_events` ou `mobility_trip_events`

### Notificações

- Usuário/lojista notificados quando rider atribuído.

### Estados

- Vazio: sem oferta ativa.
- Erro: oferta expirada, já atribuída, rider indisponível.

### Auditoria/compliance

- Recusas podem alimentar score, respeitando política transparente.

---

## R-04 — Coleta

### Wireframe textual

```text
[Header: Coleta]
[Endereço retirada]
[Contato retirada: nome | telefone]
[Pacotes: quantidade | peso | valor declarado]
[Botões: Cheguei | Coletado | Reportar problema | Ligar | Navegar]
[Upload: foto/QR/evidência]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Cheguei em | action timestamp | event |
| Coletado em | action timestamp | `picked_up_at` |
| Geo | geo JSON | event |
| Foto/evidência | file | `document_records` |
| Observação | text | event notes |

### Validações frontend

- Coletado só após Cheguei quando política exigir.
- Foto/QR obrigatório para tipos definidos.

### Validações backend

- Rider atribuído à entrega.
- Status deve permitir coleta.
- Evento append-only.
- Atualizar `shipment_status` para `PICKED_UP`.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/rider/shipments/{shipment_id}/pickup` | Dados coleta. |
| POST | `/api/rider/shipments/{shipment_id}/arrived` | Cheguei. |
| POST | `/api/rider/shipments/{shipment_id}/pickup` | Confirmar coleta. |
| POST | `/api/rider/shipments/{shipment_id}/evidence` | Anexar evidência. |

### Eventos

- `delivery.rider_arrived_pickup`
- `delivery.picked_up`
- `delivery.proof_attached`
- `delivery.pickup_problem_reported`

### Tabelas impactadas

- `delivery_shipments`
- `delivery_shipment_events`
- `document_records`

### Notificações

- Usuário: pedido coletado.
- Lojista: coleta confirmada.

### Estados

- Erro: entrega não atribuída ao rider, status inválido.

### Auditoria/compliance

- Evidência com checksum.
- Geolocalização do evento preservada.

---

## R-05 — Rota e Checkpoints

### Wireframe textual

```text
[Mapa]
[ETA | distância restante]
[Próximo destino]
[Botões: Abrir navegação | Checkpoint | Problema na rota | SOS]
[Chat/suporte]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| Geo atual | JSON | event |
| Velocidade | decimal | `mobility_trip_events.speed_kph` quando corrida |
| Distância desde último | decimal | event |
| ETA | integer | event |
| Notas | text | event |

### Validações frontend

- Localização habilitada.
- SOS sempre acessível.

### Validações backend

- Rider vinculado ao shipment/trip.
- Checkpoint append-only.
- Incidente criado quando evento indicar risco.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/rider/shipments/{id}/checkpoint` | Checkpoint entrega. |
| POST | `/api/rider/trips/{id}/checkpoint` | Checkpoint corrida. |
| POST | `/api/rider/route/problem` | Problema rota. |
| POST | `/api/rider/security/sos` | SOS. |

### Eventos

- `delivery.checkpoint_recorded`
- `mobility.checkpoint_recorded`
- `route.problem_reported`
- `security.sos.created`

### Tabelas impactadas

- `delivery_shipment_events`
- `mobility_trip_events`
- `security_incidents`
- `security_incident_events`

### Notificações

- Usuário recebe atualização de ETA/status.
- Admin recebe SOS/risco.

### Estados

- Offline: armazenar checkpoint apenas se política permitir e sincronizar depois.
- Erro: localização negada, rota indisponível.

### Auditoria/compliance

- Localização é dado sensível e deve ter retenção controlada.

---

## R-06 — Entrega Final

### Wireframe textual

```text
[Header: Entrega]
[Endereço destino]
[Contato recebedor]
[Campo PIN/código]
[Upload foto]
[Assinatura opcional]
[Observação]
[Botões: Confirmar entrega | Falha na entrega | Suporte]
```

### Campos

| Campo | Tipo | Destino |
|---|---|---|
| PIN/código | text | `proof_code_hash` validação |
| Foto | file | `document_records` |
| Assinatura | file/base64 document | `document_records` |
| Nome recebedor | text | metadata/event |
| Observação | text | event notes |
| Motivo falha | text/select | `cancellation_reason` ou event |
| Geo entrega | JSON | event |

### Validações frontend

- PIN obrigatório quando entrega exigir.
- Foto obrigatória quando política exigir.
- Motivo obrigatório para falha.

### Validações backend

- Status deve ser `IN_TRANSIT` ou compatível.
- Rider atribuído.
- Prova válida.
- Atualizar `shipment_status = DELIVERED` e `delivered_at`.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| POST | `/api/rider/shipments/{id}/deliver` | Confirmar entrega. |
| POST | `/api/rider/shipments/{id}/fail` | Falha entrega. |
| POST | `/api/rider/shipments/{id}/proof` | Prova. |

### Eventos

- `delivery.delivered`
- `delivery.failed`
- `delivery.proof_attached`

### Tabelas impactadas

- `delivery_shipments`
- `delivery_shipment_events`
- `orders`
- `transactions` para liberação settlement quando aplicável
- `document_records`

### Notificações

- Usuário: entregue/falhou.
- Lojista: entregue/falhou.
- Admin: falha recorrente ou risco.

### Estados

- Erro: PIN inválido, upload falhou, status incompatível.

### Auditoria/compliance

- Prova de entrega append-only.
- Falha exige motivo e geo quando disponível.

---

## R-07 — Ganhos Rider

### Wireframe textual

```text
[Header: Ganhos]
[Cards: hoje | semana | mês | pendente | disponível]
[Lista entregas/corridas]
[Detalhe: valor | taxa | gorjeta | status liquidação]
[Botões: Ver extrato | Solicitar saque]
```

### Campos

| Campo | Tipo | Origem |
|---|---|---|
| Ganho bruto | decimal | `transactions`/cálculo |
| Taxas | decimal | `transactions.fee_amount_brl` |
| Disponível | decimal | `wallets.balance_available_brl` |
| Pendente | decimal | `wallets.balance_pending_brl` |
| Entrega/corrida | UUID | `orders` / `delivery_shipments` / `mobility_trips` |

### Validações frontend

- Saque > 0.
- Saque <= saldo disponível.

### Validações backend

- Wallet ativa.
- Status da transação liquidado.
- Limites e antifraude.

### APIs

| Método | Endpoint | Função |
|---|---|---|
| GET | `/api/rider/earnings/summary` | Resumo. |
| GET | `/api/rider/earnings/transactions` | Extrato. |
| POST | `/api/rider/payouts` | Solicitar saque. |

### Eventos

- `rider.earnings.viewed`
- `rider.payout_requested`
- `rider.payout_completed`
- `rider.payout_failed`

### Tabelas impactadas

- `wallets`
- `transactions`
- `orders`

### Notificações

- Saque solicitado/concluído/falhou.

### Estados

- Vazio: sem ganhos no período.
- Erro: saldo insuficiente, wallet bloqueada.

### Auditoria/compliance

- Saques exigem autenticação forte quando política exigir.

---

# 7. Matriz final de permissões por superfície

| Tela | Superadmin | Operator | Analyst | Viewer | Owner lojista | Staff lojista | User PF | Rider |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Admin Login | sim | sim | sim | sim | não | não | não | não |
| Admin Dashboard | total | parcial | leitura | leitura | não | não | não | não |
| Admin Usuários | total | parcial | leitura | leitura mascarada | não | não | não | não |
| Admin Lojistas | total | parcial | leitura | leitura mascarada | não | não | não | não |
| Admin Riders | total | parcial | leitura | leitura mascarada | não | não | não | não |
| Admin Regras | total | conforme permissão | dry-run/leitura | leitura | não | não | não | não |
| Admin Billing | total | financeiro parcial | leitura | leitura mascarada | não | não | não | não |
| ERP Home | via auditoria | via auditoria | via auditoria | via auditoria | total | parcial | não | não |
| ERP Produtos | via auditoria | via auditoria | via auditoria | não | total | parcial | não | não |
| ERP Pedidos | via auditoria | via auditoria | via auditoria | não | total | parcial | não | não |
| APK Home | não | não | não | não | não | não | sim | não |
| APK Checkout | não | não | não | não | não | não | sim | não |
| APK Wallet | não | não | não | não | não | não | sim | não |
| Rider Home | não | não | não | não | não | não | não | sim |
| Rider Entrega | não | não | não | não | não | não | não | sim |
| Rider Ganhos | não | não | não | não | não | não | não | sim |

---

# 8. Checklist de QA por tela

Cada tela deve ter testes para:

- renderização inicial;
- loading;
- estado vazio;
- erro de API;
- erro de permissão;
- validação de campos obrigatórios;
- validação de formato;
- ação bem-sucedida;
- ação com conflito;
- auditoria gerada quando aplicável;
- notificação enviada quando aplicável;
- proteção contra duplo clique;
- idempotência em operações mutáveis;
- máscara de dados sensíveis;
- responsividade desktop/mobile conforme superfície.

---

# 9. Definition of Done

Uma tela só pode ser considerada pronta quando:

1. Wireframe implementado conforme este documento.
2. Campos renderizados com tipos corretos.
3. Validações frontend implementadas.
4. Validações backend implementadas.
5. APIs documentadas e testadas.
6. Eventos emitidos.
7. Tabelas persistidas corretamente.
8. Notificações disparadas quando previstas.
9. Estados loading/vazio/erro cobertos.
10. Auditoria/compliance implementados.
11. Testes unitários e integração mínimos aprovados.
12. QA validou permissões por persona.
13. Logs não expõem segredo, senha, token, documento completo ou biometria bruta.

---

# 10. Ordem recomendada de implementação

## Sprint 1 — Fundação

1. A-01 Login Admin.
2. A-02 Dashboard Admin.
3. A-03 Usuários lista.
4. A-04 Usuário detalhe.
5. U-01 Onboarding Usuário.
6. U-02 Home Usuário.

## Sprint 2 — ERP e Marketplace

1. E-01 Home ERP.
2. E-02 Perfil PJ.
3. E-03 Produtos lista.
4. E-04 Produto detalhe.
5. E-05 Estoque/WMS.
6. E-06 Anúncios.
7. U-03 Marketplace lista.
8. U-04 Produto detalhe.
9. U-05 Checkout.

## Sprint 3 — Pedidos e Delivery

1. E-07 Pedidos ERP.
2. U-06 Pedidos usuário.
3. R-01 Onboarding rider.
4. R-02 Home rider.
5. R-03 Oferta.
6. R-04 Coleta.
7. R-05 Rota.
8. R-06 Entrega final.

## Sprint 4 — Financeiro, Billing e Segurança

1. U-07 Wallet.
2. R-07 Ganhos rider.
3. A-09 Billing.
4. U-09 Segurança.
5. Admin Riders/Lojistas completo.

## Sprint 5 — Governança e Inteligência

1. A-07 Módulos.
2. A-08 Regras.
3. A-10 Integrações marketplace.
4. U-08 Helena/Chat/Agenda/Advisor.

---

# 11. Pendências intencionais para detalhamento futuro

Estas pendências não impedem o início do desenvolvimento, mas devem virar sub-specs próprias:

1. Contrato exato de carrinho, se for persistido em tabela, Redis ou runtime mobile.
2. Modelo de avaliações de produto, pedido e rider.
3. Modelo de cupons/campanhas promocionais além de gamification.
4. Contrato detalhado de notificações push/email/SMS.
5. Design system visual definitivo.
6. OpenAPI formal por endpoint.
7. Especificação de autorização interna do lojista (`MERCHANT_STAFF`) caso não use apenas roles simples.
8. Estratégia offline-first do Rider APK.
9. Contrato de mapas/roteirização.
10. Política final de retenção por país/região.
