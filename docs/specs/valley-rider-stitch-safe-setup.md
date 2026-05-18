# Valley Rider Stitch Safe Setup

Este arquivo documenta a configuração segura para MCP Stitch sem persistir chaves.

## Variaveis locais

Crie localmente, fora do Git:

```bash
export STITCH_MCP_URL="https://stitch.googleapis.com/mcp"
export STITCH_PROJECT_ID="projects/12925281642508595680"
export STITCH_API_KEY="<secret>"
```

## Regra de segredo

Nunca commitar `X-Goog-Api-Key` real.

## Uso esperado

O cliente MCP deve ler:

- `STITCH_MCP_URL`
- `STITCH_PROJECT_ID`
- `STITCH_API_KEY`

## Payload de design

Contexto: Valley Rider.
Tema: verde.
Componentes obrigatorios:

- Splash com marca Rider.
- Home mapa-first.
- Card de rota.
- Swipe para aceitar.
- Etapa de coleta.
- Etapa de entrega.
- Comprovante.
- Historico.
- Ganhos.
- Configuracoes.
- Incidente.

## Segurança

Aplicar BR-PRO-001: o design e o front devem exibir apenas repasse do entregador.
