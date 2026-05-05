# Valley MVP Delivery Plan

## Objetivo

Transformar o escopo do MVP Valley em um plano de entrega executavel, com prioridades, backlog P0, criterios de aceite, sequencia de execucao e riscos operacionais.

Este documento complementa [valley-mvp-execution-plan.md](/abs/c:/Users/ereta/.codex/worktrees/VALLEY/docs/specs/valley-mvp-execution-plan.md) com foco em entrega pratica do MVP demonstravel.

## Leitura simples

O MVP nao precisa provar que o ecossistema Valley inteiro esta pronto. Ele precisa provar que existe uma camada central de experiencia, identidade e personalizacao capaz de conectar servicos reais.

Entrega-alvo:

> Um usuario entra no Valley, ve uma home premium personalizada, entende seu nivel de confianca, acessa modulos principais e retoma acoes recentes.

## Escopo central do MVP

| area | entregavel | prioridade |
| --- | --- | --- |
| Frontend Flutter | Home premium, modulos favoritos, acoes recentes, estados visuais | P0 |
| Backend APIs | Identity Score, preferencias da home, historico de acoes | P0 |
| Seguranca e identidade | Specs tecnicas de Face ID e Voice ID | P0 |
| Integracao | Fluxo completo frontend + backend + dados reais | P0 |

## Backlog P0

### 1. Home personalizada em Flutter

Objetivo:

- entregar a experiencia principal do MVP

Tarefas:

- criar a estrutura final da home
- implementar cards de modulos
- permitir favoritar e fixar modulos
- exibir acoes recentes
- criar blocos de metricas, recomendacoes e atalhos
- implementar estados `loading`, `empty`, `error`, `success`, `active` e `disabled`

Critério de aceite:

- o usuario abre a home
- ve modulos disponiveis
- consegue fixar favoritos
- consegue visualizar uma experiencia funcional, mesmo com fallback mockado

## 2. APIs para home dinamica

Objetivo:

- substituir mock data por dados reais

Endpoints minimos sugeridos:

```http
GET /me/home
PUT /me/home/preferences
GET /me/recent-actions
GET /me/recommendations
```

Critério de aceite:

- o frontend carrega a home a partir da API
- preferencias do usuario persistem
- a camada Flutter consegue diferenciar sucesso, vazio e erro sem quebrar a navegação

## 3. Identity Score

Objetivo:

- entregar um score inicial de identidade sem criar um sistema biometrico pesado no MVP

Endpoint minimo sugerido:

```http
GET /me/identity-score
```

Fontes sugeridas:

- `users.risk_level`
- logs de seguranca
- historico transacional
- eventos de autenticacao
- sinais comportamentais ja existentes
- verificacoes operacionais ja implementadas

Resposta de referencia:

```json
{
  "score": 82,
  "level": "high_trust",
  "signals": [
    {
      "name": "Login seguro",
      "status": "positive"
    },
    {
      "name": "Historico transacional",
      "status": "positive"
    },
    {
      "name": "Risco da conta",
      "status": "low"
    }
  ]
}
```

Critério de aceite:

- o usuario ve um score simples
- o score e explicavel
- o score usa dados existentes, sem depender de biometria avancada

## 4. Specs tecnicas de Face ID e Voice ID

Objetivo:

- cumprir a abordagem `spec-first` sem construir IA biometrica complexa no MVP

Entregaveis alvo:

- `docs/specs/identity/face-id.md`
- `docs/specs/identity/voice-id.md`

Cada spec deve conter:

- objetivo
- escopo do MVP
- dados permitidos
- dados proibidos
- fluxo de consentimento
- modelo de armazenamento
- metadados de auditoria
- riscos de privacidade
- estrategia futura

Critério de aceite:

- as specs deixam explicito que o MVP nao armazena biometria bruta
- a autenticacao biometrica avancada fica registrada como evolucao futura

## Sequencia recomendada

### Semana 1 - UI e contrato de APIs

- finalizar a estrutura visual da home em Flutter
- criar mock data controlado
- definir contratos dos endpoints
- escrever specs iniciais de Face ID e Voice ID

### Semana 2 - Backend minimo

- implementar APIs da home
- implementar API do Identity Score
- criar persistencia de preferencias
- registrar eventos simples de acoes recentes

### Semana 3 - Integracao

- conectar Flutter as APIs reais
- tratar erros e estados vazios
- ajustar loading, skeletons e mensagens
- validar o fluxo completo ponta a ponta

### Semana 4 - Polimento e entrega

- testes E2E
- revisao de UX
- revisao de seguranca
- documentacao final
- checklist de release

## Gates de aceite do MVP

### Gate 1 - UI funcional

- home abre sem crash
- blocos principais aparecem com fallback seguro
- favoritos e atalhos respondem

### Gate 2 - Dados reais

- `/me/home`, `/me/home/preferences`, `/me/recent-actions` e `/me/recommendations` respondem
- o frontend para de depender exclusivamente de mock

### Gate 3 - Identidade explicavel

- `/me/identity-score` responde com score, nivel e sinais
- o score pode ser explicado sem opacidade tecnica

### Gate 4 - Integracao demonstravel

- o fluxo completo frontend + backend + dados reais funciona em ambiente publico
- os estados `loading`, `empty`, `error` e `success` ficam visiveis e coerentes

## Riscos principais

| risco | impacto | mitigacao |
| --- | ---: | --- |
| Tentar incluir modulos demais no MVP | Alto | limitar o MVP a home, identidade, personalizacao e retomada |
| Identity Score virar projeto complexo | Alto | agregar sinais existentes em vez de inventar motor antifraude pesado |
| Frontend bonito sem dados reais | Medio | definir e implementar APIs cedo |
| Specs biometricas vagas | Medio | escrever escopo, privacidade, proibicoes e estrategia futura |
| Microsservicos demais para demo | Alto | usar camada agregadora ou BFF no MVP |

## Prioridade pratica

Ordem de execucao recomendada:

1. Home Flutter
2. Contratos das APIs
3. Persistencia de preferencias e acoes recentes
4. Identity Score
5. Specs Face ID e Voice ID
6. Integracao ponta a ponta
7. Polimento, QA e release

## Definicao de pronto

O MVP Valley fica pronto quando:

- a home premium estiver funcional em Flutter
- preferencias da home persistirem
- acoes recentes aparecerem com dados reais
- o usuario visualizar um Identity Score explicavel
- Face ID e Voice ID estiverem especificados em modo spec-first
- o fluxo completo puder ser demonstrado publicamente sem botoes mortos
