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
- [ ] Validar links publicos principais e atualizar evidencias finais.

## Evidencias

- Plano iniciado a partir da solicitacao de configurar `brasildesconto.com.br` como link oficial publico e criar links por modulo.
- Tunnel alvo informado e mantido: `valley-admin` (`80a75594-5129-469f-8cce-4a938ac48e06`).
- `scripts/plan_valley_module_subdomains.py` agora gera `59` registros: `brasildesconto.com.br`, `admin.brasildesconto.com.br`, `*.admin.brasildesconto.com.br` e `56` workspaces exatos.
- `scripts/apply_valley_public_domains.ps1` criado como entrada unica para DNS + Tunnel, com status sanitizado em `tmp/runtime/valley-public-domains-automation.json`.
- Runtime local validado: Host `brasildesconto.com.br` em `127.0.0.1:8085/` retorna `302 Location: /product/`; Host `admin.brasildesconto.com.br` retorna `200`; Host `stock.admin.brasildesconto.com.br` retorna `200`.
- Servidor local do admin reiniciado em `0.0.0.0:8085` com `healthz=200`.

## Bloqueios

- A Cloudflare recusou a aplicacao por API com `Authentication error` e anteriormente recusou os tokens por `Client IP Address Filtering` nos IPs `45.185.45.253` e `2804:2238:71e:1800:ccaa:e713:ea14:bd16`.
- O Tunnel remoto atualmente tem rota `admin.brasildesconto.com.br` limitada ao path `^/erp`, por isso `https://admin.brasildesconto.com.br/healthz` e `/` retornam `404` antes de chegar na origem local.

## Proxima acao

- Desbloquear/escalar o token Cloudflare com `Zone DNS Edit` e `Cloudflare Tunnel Write` sem filtro de IP, entao reexecutar `scripts\apply_valley_public_domains.ps1` para aplicar a configuracao remota e fechar a validacao final.
