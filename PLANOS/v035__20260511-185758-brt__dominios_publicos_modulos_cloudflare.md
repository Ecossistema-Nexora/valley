# v035 - Dominios Publicos, Modulos Admin e Cloudflare Persistente

## Resumo

- Definir `brasildesconto.com.br` como link oficial publico da marca Valley e acesso dos usuarios.
- Manter `admin.brasildesconto.com.br` como painel admin central.
- Publicar workspaces administrativos por subdominio, incluindo `*.admin.brasildesconto.com.br` e os registros exatos de cada modulo.
- Automatizar DNS + Cloudflare Tunnel em scripts idempotentes, sem versionar tokens ou segredos.

## Checklist

- [x] Criar plano persistente v035 para dominio publico e workspaces Cloudflare. Concluido em 2026-05-11 18:57:58 BRT.
- [x] Ajustar gerador de DNS para incluir site publico, admin, wildcard e todos os modulos. Concluido em 2026-05-11 19:04:29 BRT.
- [x] Ajustar runtime para separar site publico de produto e workspaces admin. Concluido em 2026-05-11 19:07:52 BRT.
- [x] Criar entrada unica automatica para aplicar DNS e Tunnel de forma idempotente. Concluido em 2026-05-11 19:05:41 BRT.
- [x] Executar automacao Cloudflare com token disponivel e registrar bloqueios externos se a API recusar. Concluido em 2026-05-11 19:05:32 BRT.
- [x] Validar links publicos principais e atualizar evidencias finais. Concluido em 2026-05-11 22:30:25 BRT.
- [x] Fechar decisao de HTTPS para subdominios profundos: manter custo zero com aliases de primeiro nivel cobertos pelo Universal SSL. Concluido em 2026-05-12 00:24:45 BRT.

## Evidencias

- Plano iniciado a partir da solicitacao de configurar `brasildesconto.com.br` como link oficial publico e criar links por modulo.
- Tunnel alvo informado e mantido: `valley-admin` (`80a75594-5129-469f-8cce-4a938ac48e06`).
- `scripts/plan_valley_module_subdomains.py` agora gera `59` registros: `brasildesconto.com.br`, `admin.brasildesconto.com.br`, `*.admin.brasildesconto.com.br` e `56` workspaces exatos.
- `scripts/apply_valley_public_domains.ps1` criado como entrada unica para DNS + Tunnel, com status sanitizado em `tmp/runtime/valley-public-domains-automation.json`.
- Runtime local validado: Host `brasildesconto.com.br` em `127.0.0.1:8085/` retorna `302 Location: /product/`; Host `admin.brasildesconto.com.br` retorna `200`; Host `stock.admin.brasildesconto.com.br` retorna `200`.
- Servidor local do admin reiniciado em `0.0.0.0:8085` com `healthz=200`.
- Nova tentativa com token ativo em 2026-05-11 22:08:59 BRT: `tokens/verify` retornou ativo, mas `zone-read` retornou `9109 Cannot use the access token from location` para IPv6 e IPv4; aplicacao automatica continuou bloqueada.
- Nova tentativa em 2026-05-11 22:16:30 BRT: IPv6 continuou bloqueado em `2804:2238:71e:1800:ccaa:e713:ea14:bd16`, IPv4 continuou bloqueado em `45.185.45.253`, e a automacao persistente voltou `apply_status=blocked_cloudflare_api`.
- Tentativa bem-sucedida em 2026-05-11 22:30:25 BRT: leitura de zone/DNS/tunnel retornou HTTP 200 e `scripts\apply_valley_public_domains.ps1` concluiu com `apply_status=applied` e `tunnel_apply_status=applied`.
- Configuracao remota do Tunnel validada com ingress raiz para `brasildesconto.com.br`, `admin.brasildesconto.com.br` e `*.admin.brasildesconto.com.br`, todos apontando para `http://192.168.1.2:8085`.
- DNS validado para `brasildesconto.com.br`, `admin.brasildesconto.com.br`, `*.admin.brasildesconto.com.br`, `stock.admin.brasildesconto.com.br`, `01-reply.admin.brasildesconto.com.br` e `47-docs.admin.brasildesconto.com.br`.
- Links principais validados externamente: `https://admin.brasildesconto.com.br/healthz` HTTP 200, `https://admin.brasildesconto.com.br/` HTTP 200, `https://brasildesconto.com.br/` HTTP 200 com final em `/product/`, e `https://brasildesconto.com.br/product/` HTTP 200.
- Modulos `*.admin.brasildesconto.com.br` validam via HTTP, mas HTTPS falha no handshake TLS porque a zona Free/sem ACM nao cobre wildcard profundo `*.admin.brasildesconto.com.br`.
- Total TLS testado via API em 2026-05-11 22:30:25 BRT; `GET /zones/{zone_id}/acm/total_tls` retornou `enabled=false` e `POST` retornou erro `1450`, exigindo Advanced Certificate Manager.
- Nova tentativa em 2026-05-12 00:06:01 BRT: Total TLS continuou `enabled=false` e o `POST /acm/total_tls` continuou retornando erro `1450`; `stock.admin`, `01-reply.admin` e `47-docs.admin` retornaram HTTP 200 por `http://`, mas HTTPS continuou sem handshake TLS valido.
- O `permission_group` informado (`5b1d209212064a84aae4fb68e3908333`) nao pode ser inspecionado pelo token atual; `/user/tokens/permission_groups` retornou `403 Valid user-level authentication not found`.
- Decisao custo zero aplicada em 2026-05-12 00:24:45 BRT: o manifesto passou a gerar aliases HTTPS de primeiro nivel cobertos por `*.brasildesconto.com.br`, evitando Advanced Certificate Manager.
- `scripts\apply_valley_public_domains.ps1` aplicou `137` registros com `apply_status=applied` e `tunnel_apply_status=applied`, incluindo `56` aliases admin e `22` aliases ERP lojista.
- Login e ERP lojista validados com HTTPS 200 em `https://lojista.brasildesconto.com.br/`, `https://erp-lojista.brasildesconto.com.br/`, `https://pdv-lojista.brasildesconto.com.br/`, `https://armazem-lojista.brasildesconto.com.br/`, `https://metricas-lojista.brasildesconto.com.br/`, `https://campanhas-lojista.brasildesconto.com.br/`, `https://relatorios-lojista.brasildesconto.com.br/`, `https://financeiro-lojista.brasildesconto.com.br/` e `https://integracao-lojista.brasildesconto.com.br/`.
- Todos os `22` aliases do ERP lojista foram validados com HTTPS 200 em 2026-05-12, incluindo cadastro, perfil, contabil, pedidos, produtos, clientes, fiscal, estoque, logistica, atendimento, equipe, seguranca e configuracoes.
- Aliases admin de modulo validados com HTTPS 200 em `https://stock-admin.brasildesconto.com.br/`, `https://01-reply-admin.brasildesconto.com.br/` e `https://47-docs-admin.brasildesconto.com.br/`.

## Bloqueios

- Bloqueios anteriores de token, rate limit e rota `^/erp` do Tunnel foram resolvidos em 2026-05-11 22:30:25 BRT.
- Subdominios profundos `*.admin.brasildesconto.com.br` permanecem como compatibilidade HTTP/legado; os links oficiais HTTPS sem custo usam aliases de primeiro nivel.

## Proxima acao

- Usar os aliases HTTPS de primeiro nivel como links oficiais dos modulos e do ERP lojista enquanto a conta permanecer no plano Free.
