# Valley Public Domains v035

## Objetivo

- Link publico oficial da marca e usuarios: `https://brasildesconto.com.br`
- Painel admin central: `https://admin.brasildesconto.com.br`
- Workspaces admin por modulo: `https://stock.admin.brasildesconto.com.br`, `https://01-reply.admin.brasildesconto.com.br` ... `https://47-docs.admin.brasildesconto.com.br`

## Cloudflare

Tunnel:

- Nome: `valley-admin`
- ID: `80a75594-5129-469f-8cce-4a938ac48e06`
- Target DNS: `80a75594-5129-469f-8cce-4a938ac48e06.cfargotunnel.com`
- Origem: `http://192.168.1.2:8085`

Registros obrigatorios:

- `brasildesconto.com.br` CNAME -> `80a75594-5129-469f-8cce-4a938ac48e06.cfargotunnel.com`
- `admin.brasildesconto.com.br` CNAME -> `80a75594-5129-469f-8cce-4a938ac48e06.cfargotunnel.com`
- `*.admin.brasildesconto.com.br` CNAME -> `80a75594-5129-469f-8cce-4a938ac48e06.cfargotunnel.com`
- Registros exatos dos 56 workspaces -> `admin.brasildesconto.com.br`

Public Hostnames do Tunnel:

- `brasildesconto.com.br` -> `http://192.168.1.2:8085`
- `admin.brasildesconto.com.br` -> `http://192.168.1.2:8085`
- `*.admin.brasildesconto.com.br` -> `http://192.168.1.2:8085`

Estado validado em 2026-05-11 22:30 BRT:

- O conector `cloudflared` esta online.
- A configuracao remota do Tunnel foi aplicada sem path restritivo para `brasildesconto.com.br`, `admin.brasildesconto.com.br` e `*.admin.brasildesconto.com.br`.
- `https://admin.brasildesconto.com.br/healthz`, `https://admin.brasildesconto.com.br/`, `https://brasildesconto.com.br/` e `https://brasildesconto.com.br/product/` retornaram HTTP 200.
- Os hosts profundos `*.admin.brasildesconto.com.br` resolvem no DNS e roteiam por HTTP, mas HTTPS exige certificado adicional porque o Universal SSL do plano atual nao cobre wildcard profundo.
- Total TLS foi testado via API e retornou erro `1450`, indicando necessidade de Advanced Certificate Manager.

## Automacao

Comando canonico:

```powershell
$env:CLOUDFLARE_API_TOKEN='TOKEN_COM_ZONE_DNS_EDIT_E_TUNNEL_WRITE'
$env:CLOUDFLARE_ZONE_ID='ec42e46c3012a03fa30b04e96abc553c'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\apply_valley_public_domains.ps1
```

O script nao grava o token. Ele gera:

- `output/deployment/valley-module-subdomains.json`
- `tmp/runtime/valley-public-domains-automation.json`

Se o token estiver bloqueado por Client IP Address Filtering, o status fica `blocked` e os IPs publicos detectados ficam registrados no JSON de runtime para liberar no painel Cloudflare sem expor o segredo.

IPs observados nesta maquina:

- IPv4: `45.185.45.253`
- IPv6: `2804:2238:71e:1800:ccaa:e713:ea14:bd16`

## Runtime

- `brasildesconto.com.br/` redireciona para `/product/`.
- `admin.brasildesconto.com.br/` abre o admin central.
- `*.admin.brasildesconto.com.br/` abre o admin focado no workspace pelo subdominio.

## Pendencia TLS dos Modulos

Para usar HTTPS nos links exatos `stock.admin.brasildesconto.com.br`, `01-reply.admin.brasildesconto.com.br` etc., ha duas opcoes:

- Ativar Advanced Certificate Manager/Total TLS na Cloudflare.
- Criar aliases HTTPS de primeiro nivel, por exemplo `stock-admin.brasildesconto.com.br`, que ficam cobertos pelo wildcard padrao `*.brasildesconto.com.br`.
