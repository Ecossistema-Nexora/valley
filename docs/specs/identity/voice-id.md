<!--
PROPOSITO: Especificar a camada de Voice ID do Valley para operacoes sensiveis.
CONTEXTO: Este documento define consentimento, enrolment, dados permitidos e limites do MVP.
REGRAS: Nao armazenar audio bruto fora da governanca SECURITY e manter trilha auditavel.
-->

# Voice ID - MVP Spec

## Objetivo

Definir a camada de Voice ID do MVP Valley como reforco opcional de autenticacao e aceite sensivel, mantendo abordagem `spec-first`, custo controlado e escopo leve.

## Escopo do MVP

O MVP cobre:

- desenho de consentimento
- definicao de uso como reforco de autenticacao
- armazenamento minimo de referencia segura e metadados
- rastreabilidade de tentativas e decisoes

O MVP nao cobre:

- pipeline pesado de IA de voz
- treinamento de modelo de voz do usuario no Valley
- biometria vocal continua
- analise massiva de audio historico

## Dados permitidos

- `user_id`
- identificador da credencial vocal
- hash, template ou referencia segura aprovada pelo dominio `SECURITY`
- metadados de enrolment
- metadados de consentimento
- estado da credencial
- eventos de tentativa e verificacao

## Dados proibidos

- armazenamento de audio bruto permanente como padrao
- reutilizacao de voz para fins de marketing, recomendacao ou perfilamento
- uso de audio coletado fora do consentimento do usuario
- pipeline de voz sempre ativo no MVP

## Fluxo de consentimento

1. O usuario escolhe ativar Voice ID.
2. O sistema explica finalidade, limites e riscos.
3. O usuario fornece consentimento explicito.
4. O enrolment registra apenas referencia segura e metadados necessarios.
5. O evento e auditado.

## Fluxo operacional do MVP

1. O sistema identifica uma operacao com risco aumentado.
2. O usuario recebe step-up opcional ou exigido por politica.
3. A verificacao vocal ocorre em modo leve.
4. O resultado gera evento `positive`, `negative` ou `review`.
5. O fluxo sensivel continua, bloqueia ou vai para revisao.

## Modelo de armazenamento

Superficie recomendada:

- `security_biometric_credentials`
- `security_signal_logs`
- eventos derivados de autenticacao

Regras:

- credencial sempre ancorada em `users.user_id`
- audio bruto nao e o artefato operacional padrao
- trilha append-only para decisoes sensiveis

## Metadados de auditoria

Campos minimos recomendados:

- `credential_id`
- `user_id`
- `event_type`
- `challenge_type`
- `event_status`
- `review_required`
- `created_at`
- `origin_surface`

## Riscos de privacidade

- risco de captura de dado sensivel por audio
- risco de fraude por imitacao
- risco de retencao indevida de voz
- risco de elevar custo operacional cedo demais

Mitigacao:

- escopo leve no MVP
- sem armazenamento bruto por padrao
- uso apenas em casos sensiveis
- revisao humana quando houver ambiguidade

## Estrategia futura

Fase futura possivel:

- motor vocal mais robusto
- antifraude por sinais multimodais
- combinacao com Face ID e Identity Score
- politicas adaptativas por risco e contexto

## Critério de aceite

- a spec deixa claro que Voice ID no MVP e leve e spec-first
- nao existe dependencia de audio bruto persistido
- o fluxo de consentimento e auditoria esta definido
- a evolucao futura fica separada do corte inicial
