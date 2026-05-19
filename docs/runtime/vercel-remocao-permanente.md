# Remocao permanente do Vercel no Valley

## Objetivo
Este manual registra a remocao definitiva de configuracoes e pontos de integracao do Vercel no repositorio Valley, para evitar reativacoes acidentais e reduzir custo operacional com plataforma nao utilizada.

## O que foi removido
- Arquivo `vercel.json` na raiz (configuracao de deploy Vercel).

## O que foi alterado
- `frontend/flutter/lib/src/data/valley_repository.dart`
  - Host remoto trocado de `https://valley-alpha.vercel.app` para `https://admin.brasildesconto.com.br`.
  - Comentarios tecnicos adicionados explicando justificativa, finalidade e integracao do endpoint.

## Integracao resultante
- O app Flutter continua com estrategia resiliente:
  - tenta leitura remota do manifesto/modulos/release;
  - usa fallback local em assets quando a rede falha.

## Checklist de validacao
1. Confirmar ausencia de `vercel.json` no versionamento Git.
2. Confirmar ausencia de URL `*.vercel.app` no codigo rastreado.
3. Executar validacao minima do Flutter (`flutter analyze` no modulo, quando ambiente possuir SDK).

## Motivacao de arquitetura e custo
- Menos acoplamento com provedor de hosting descontinuado.
- Menor risco de deploy paralelo indevido.
- Base unica de endpoint oficial simplifica suporte e observabilidade.
