<!--
PROPOSITO: Especificar a camada de Face ID do Valley para operacoes sensiveis.
CONTEXTO: Este documento define consentimento, enrolment, dados permitidos e limites do MVP.
REGRAS: Nao armazenar biometria bruta fora da governanca SECURITY e manter trilha auditavel.
-->

# Face ID - MVP Spec

## Objetivo

Definir a camada de Face ID do MVP Valley como um mecanismo de confianca para operacoes sensiveis, sem introduzir armazenamento de biometria bruta fora da governanca do modulo `SECURITY`.

## Escopo do MVP

O MVP cobre:

- consentimento explicito do usuario para ativacao
- enrolment vinculado a `users.user_id`
- armazenamento apenas de template seguro, hash, metadados tecnicos e trilha auditavel
- uso como reforco de autenticacao em fluxos sensiveis

O MVP nao cobre:

- biometria facial avancada com IA proprietaria treinada no Valley
- coleta massiva de face
- armazenamento de video bruto de face como padrao operacional
- decisao automatica irreversivel sem trilha de auditoria

## Dados permitidos

- `user_id`
- identificador da credencial biometrica
- tipo de credencial: `face_id`
- hash ou template seguro
- metadados de enrolment
- metadados de liveness
- versao do motor biometrico usado
- timestamps de criacao, rotacao e revogacao
- status da credencial
- logs de tentativa, sucesso, falha e revogacao

## Dados proibidos

- imagem bruta permanente sem justificativa legal e tecnica
- video bruto permanente como modelo padrao
- embedding biometrico sem trilha de governanca
- uso da biometria para publicidade, perfilamento comercial ou recomendacao
- compartilhamento da biometria com modulos nao ligados a seguranca

## Fluxo de consentimento

1. O usuario inicia a ativacao de Face ID.
2. O sistema mostra finalidade, limites e riscos.
3. O usuario confirma consentimento explicito.
4. O enrolment cria uma credencial vinculada a `users.user_id`.
5. O evento de seguranca e registrado com auditoria.

## Fluxo operacional do MVP

1. Usuario solicita operacao sensivel.
2. O sistema verifica se existe credencial facial ativa.
3. Se existir, solicita confirmacao facial como reforco.
4. O resultado gera evento de sucesso, falha ou revisao.
5. O fluxo de origem recebe decisao rastreavel.

## Modelo de armazenamento

Superficie relacional esperada:

- `security_biometric_credentials`
- `security_signal_logs`
- `security_incidents`, quando houver evento relevante

Regras:

- vinculo obrigatorio com `users.user_id`
- biometria sempre referenciada como credencial de seguranca
- dados sensiveis guardados sob o dominio `SECURITY`
- auditoria append-only para eventos operacionais

## Metadados de auditoria

Campos minimos recomendados:

- `credential_id`
- `user_id`
- `event_type`
- `event_status`
- `event_origin`
- `device_fingerprint`, quando permitido
- `ip_hash`, quando permitido pela politica
- `created_at`
- `review_required`

## Riscos de privacidade

- captura de dado altamente sensivel
- risco de reutilizacao indevida
- risco de falso positivo ou falso negativo
- risco de ampliar superficie de ataque

Mitigacao:

- nao armazenar biometria bruta como padrao
- usar consentimento granular
- limitar uso a autenticacao sensivel
- manter trilha de auditoria e revogacao

## Estrategia futura

Fase futura possivel:

- hardening de liveness
- device binding mais forte
- politicas de step-up por risco
- integracao com score de identidade em tempo real

## Critério de aceite

- a spec deixa claro que o MVP nao depende de biometria bruta persistida
- o fluxo de consentimento esta definido
- o modelo de armazenamento esta vinculado a `SECURITY`
- a auditoria e obrigatoria
