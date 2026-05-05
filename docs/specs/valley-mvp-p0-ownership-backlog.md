# Valley MVP P0 Ownership Backlog

## Objetivo

Desdobrar o plano de entrega do MVP em frentes de execucao alinhadas ao modelo de ownership do workspace.

Referencias principais:

- [valley-mvp-delivery-plan.md](/abs/c:/Users/ereta/.codex/worktrees/VALLEY/docs/specs/valley-mvp-delivery-plan.md)
- [config/codex-agent-squad.json](/abs/c:/Users/ereta/.codex/worktrees/VALLEY/config/codex-agent-squad.json)

## Frentes P0

| frente | owner primario | prioridade | dependencia |
| --- | --- | --- | --- |
| Home premium Flutter | STARK | P0 | contratos de API e dados fallback |
| APIs `/me/home` e derivados | THOR + BANNER | P0 | modelo de dados e camada de runtime |
| Identity Score | BANNER + THOR | P0 | sinais existentes em identity, security e pay |
| Specs Face ID e Voice ID | BANNER + STEVE | P0 | alinhamento com SECURITY e governanca |
| Integracao ponta a ponta | THOR + STARK + STEVE | P0 | entrega minima das quatro frentes acima |

## Backlog executavel

### STARK - Home premium Flutter

Arquivos-alvo provaveis:

- `frontend/flutter/lib/src/ui/valley_home_shell.dart`
- `frontend/flutter/lib/src/ui/valley_product_shell.dart`

Tarefas:

- consolidar estrutura final da home
- expor modulos favoritos e atalhos recentes
- materializar estados `loading`, `empty`, `error`, `success`, `active` e `disabled`
- preservar experiencia premium e modular

Critério de aceite:

- home abre sem crash
- favoritos e acoes recentes aparecem
- estados visuais sao coerentes

### THOR + BANNER - APIs da home

Alvo:

- BFF ou camada agregadora do MVP

Endpoints minimos:

```http
GET /me/home
PUT /me/home/preferences
GET /me/recent-actions
GET /me/recommendations
```

Tarefas:

- definir payloads canonicos
- escolher persistencia de preferencias
- entregar fallback seguro para usuario sem historico

Critério de aceite:

- frontend carrega a home a partir de dados reais
- preferencias persistem entre sessoes

### BANNER + THOR - Identity Score

Endpoint:

```http
GET /me/identity-score
```

Sinais minimos:

- `users.risk_level`
- eventos de seguranca
- historico de transacoes
- sinais operacionais ja existentes

Tarefas:

- definir algoritmo simples e explicavel
- mapear sinais e pesos
- expor score, nivel e sinais ao frontend

Critério de aceite:

- score e retornado sem depender de biometria avancada
- resposta e explicavel e auditavel

### BANNER + STEVE - Specs de identidade

Arquivos:

- `docs/specs/identity/face-id.md`
- `docs/specs/identity/voice-id.md`

Tarefas:

- fechar escopo do MVP
- definir dados permitidos e proibidos
- registrar fluxo de consentimento e auditoria

Critério de aceite:

- biometria bruta nao vira dependencia do MVP
- limites e estrategia futura ficam claros

### THOR + STARK + STEVE - Integracao e gate final

Tarefas:

- conectar Flutter as APIs reais
- validar estados vazios e mensagens de erro
- validar fluxo publico demonstravel
- registrar checklist de release

Critério de aceite:

- home, identidade e retomada de acoes funcionam ponta a ponta
- sem botoes mortos no fluxo demonstrado

## Sequencia recomendada de execucao

1. Specs Face ID e Voice ID
2. Contratos das APIs `/me/*`
3. Persistencia de preferencias e acoes recentes
4. Home Flutter integrada
5. Identity Score
6. Integracao final e release gate

## Gate final do MVP

O MVP pode ser considerado pronto quando:

- a home premium estiver funcional em Flutter
- as APIs `/me/home`, `/me/home/preferences`, `/me/recent-actions`, `/me/recommendations` e `/me/identity-score` responderem
- o Identity Score estiver visivel e explicavel
- Face ID e Voice ID estiverem cobertos por specs `spec-first`
- o fluxo completo puder ser demonstrado publicamente
