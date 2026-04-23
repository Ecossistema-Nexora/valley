# Valley MVP Identity Front

## Proposito

Esta especificacao fecha a frente de identidade unica do MVP sem criar um novo modulo fora do registro canonico V47.

A identidade do MVP sera entregue como uma camada transversal apoiada em:

- nucleo relacional de identidade em `users`, `wallets` e `led_cards`
- trilha de seguranca e biometria em `SECURITY`
- score de risco e reputacao puxado por `PAY`, `SECURITY` e `MARKETPLACE`

## Principio

Face ID, Voice ID e Identity Score nao sao um produto separado.

Sao mecanismos de confianca que habilitam:

- pagamento
- onboarding de seller
- aprovacoes sensiveis
- antifraude
- trilha juridica e documental

## Escopo Do MVP

### 1. Face ID

Entrega prevista:

- reaproveitar a trilha de `security.biometric.enrolled`
- ancorar credenciais em `security_biometric_credentials`
- manter vinculacao forte com `users.user_id`
- permitir ativacao de credencial principal para operacoes sensiveis

Regra de ouro:

- nao guardar biometria bruta fora da estrategia segura do modulo `SECURITY`
- trabalhar com hash, template seguro, metadado de liveness e trilha de auditoria

### 2. Voice ID

Entrega prevista:

- modo `spec-first`
- sem criar coleta massiva nem processamento caro no MVP
- usar como reforco de autenticacao e aceite sensivel

Regra de ouro:

- nao abrir um pipeline caro de IA de voz no corte inicial
- manter desenho leve, acionado sob demanda, com prova de consentimento

### 3. Identity Score

Entrega prevista:

- score agregado e explicavel
- nao criar outro modulo nem outro cadastro
- consolidar sinais que ja existem ou ja cabem no backbone atual

Fontes de sinal previstas:

- `users.risk_level`
- eventos de `security_signal_logs`
- historico de `transactions`
- validacoes de `sale_validation_events`
- reputacao operacional de `merchant_storefronts`

Uso no MVP:

- antifraude de pagamento
- aprovacao de seller
- bloqueio, alerta ou revisao manual
- prioridade de conciliacao e monitoramento

## Donos Da Frente

- `core_identity_wallets`
- `SECURITY`
- `PAY`
- `MARKETPLACE`
- `LEGAL`, quando houver prova de aceite sensivel

## Entidades E Evidencias

### Relacional

- `users`
- `wallets`
- `led_cards`
- `transactions`
- `merchant_storefronts`
- `sale_validation_events`
- `security_biometric_credentials`
- `security_incidents`

### Eventos

- `security.biometric.enrolled`
- `security.incident.closed`
- `pay.transaction.posted`
- `marketplace.sale.validated`

## Regras De Execucao

1. Nao criar um novo modulo de identidade fora do V47.
2. Nao duplicar cadastro de usuario.
3. Nao armazenar biometria crua em superficies sem governanca.
4. Fazer o score nascer como perfil agregado de risco e reputacao, nao como numero magico isolado.
5. Toda decisao sensivel precisa ter evidencia rastreavel.

## Sequencia Recomendada

### Etapa 1

- ativar Face ID sobre a base ja existente de seguranca
- amarrar usuario, credencial biometrica e evento de enrolment

### Etapa 2

- definir Voice ID em modo leve, sem ampliar custo fixo cedo
- ligar aceite e reforco de autenticacao

### Etapa 3

- consolidar Identity Score para pagamento, seller e revisao de risco
- expor resultado em superficie operacional simples

## Resultado Esperado

- menos fraude
- mais confianca no onboarding
- mais seguranca em operacoes sensiveis
- base objetiva para antifraude e reputacao sem inflar o MVP
