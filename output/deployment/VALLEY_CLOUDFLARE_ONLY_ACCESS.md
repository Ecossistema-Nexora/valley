# Valley - Acesso Publico Cloudflare Only

Atualizado em BRT: 2026-05-12

## Decisao Operacional

O runtime publico do Valley deve usar somente Cloudflare para acesso externo.
Tailscale fica desativado como rota operacional do produto e nao deve ser usado
como base publica do APK, do portal ou dos paineis.

## Links Oficiais

### Admin

- Painel admin: <https://admin.brasildesconto.com.br>
- Site publico: <https://brasildesconto.com.br>
- STOCK: <https://stock-admin.brasildesconto.com.br>
- Marketplace: <https://marketplace-admin.brasildesconto.com.br>
- Financeiro: <https://finance-admin.brasildesconto.com.br>
- Lojistas: <https://merchants-admin.brasildesconto.com.br>

### Lojista

- Login lojista: <https://lojista.brasildesconto.com.br>
- ERP lojista: <https://erp-lojista.brasildesconto.com.br>
- PDV: <https://pdv-lojista.brasildesconto.com.br>
- Armazem: <https://armazem-lojista.brasildesconto.com.br>
- Estoque: <https://estoque-lojista.brasildesconto.com.br>
- Inventario: <https://inventario-lojista.brasildesconto.com.br>
- Logistica: <https://logistica-lojista.brasildesconto.com.br>
- Transportadora: <https://transportadora-lojista.brasildesconto.com.br>

### Usuario

- Portal publico: <https://brasildesconto.com.br>
- Produto web/mobile: <https://brasildesconto.com.br/product>

## Estado Local

- Container Docker Tailscale parado: `valley-tailscale-mcp`.
- Base release mobile/web: `https://brasildesconto.com.br`.
- Validacao autonoma passa a usar `cloudflare_base_url`.
- Rotas locais continuam apenas para desenvolvimento explicito via ambiente ou origem local.

## Arquivos Alterados

- `frontend/flutter/lib/src/data/product_api_repository.dart`
- `config/valley_mvp_autonomous_closure.json`
- `scripts/run_valley_mvp_autonomous_closure.ps1`

