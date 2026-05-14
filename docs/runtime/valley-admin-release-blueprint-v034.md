<!--
PROPOSITO: Registrar o blueprint de release do painel administrativo Valley v034.
CONTEXTO: Este documento consolida URL publica, healthcheck, APIs operacionais, tunnel e gates de release.
REGRAS: Validar Cloudflare, healthz, API admin e ausencia de segredos antes de distribuir artefatos.
-->

# Valley Admin Release Blueprint v034

## Escopo

- Superficie: painel administrativo Valley.
- URL publica fixa: `https://admin.brasildesconto.com.br/`
- Healthcheck: `https://admin.brasildesconto.com.br/healthz`
- API operacional: `https://admin.brasildesconto.com.br/api/admin-data`
- Tunnel: `valley-admin` (`80a75594-5129-469f-8cce-4a938ac48e06`)
- Origem Cloudflare: `http://192.168.1.2:8085`

## Release Gates

- Cloudflare named tunnel deve estar `healthy`.
- `/healthz` deve retornar `status=ok` e `service=valley-admin`.
- `/` deve servir `Valley Admin ERP`.
- `/api/admin-imported-products-pricing` deve refletir a politica ativa do STOCK.
- Nenhum segredo ou token deve ser gravado no Git.

## Estado v034

- Dominio fixo validado com HTTP 200 em `/healthz`, `/`, `/product` e `/api/product-shell`.
- Manifesto publico atualizado em `tmp/runtime/valley-admin-public-runtime.json`.
- STOCK em modo de atividade com auto-pause desativado por override temporario registrado fora da politica permanente.

## Link De Entrega

`https://admin.brasildesconto.com.br/`
