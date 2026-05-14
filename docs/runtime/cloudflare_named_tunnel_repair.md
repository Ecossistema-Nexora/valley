<!--
PROPOSITO: Registrar diagnostico e reparo do named tunnel Cloudflare do painel Valley.
CONTEXTO: Este runbook orienta recuperacao do dominio admin.brasildesconto.com.br e do tunnel valley-admin.
REGRAS: Nao versionar tokens Cloudflare, cert.pem ou segredos de tunnel; validar healthcheck publico apos qualquer troca.
-->

# Reparo do named tunnel `valley-admin`

## Estado diagnosticado

- Dominio: `https://admin.brasildesconto.com.br`
- DNS atual: `admin.brasildesconto.com.br` aponta para `80a75594-5129-469f-8cce-4a938ac48e06.cfargotunnel.com`.
- Tunnel Cloudflare: `valley-admin`
- Tunnel ID: `80a75594-5129-469f-8cce-4a938ac48e06`
- Conta Cloudflare: `474fc26bf9c6bcf5e1a84b7f63a516d8`
- Sintoma publico: `Cloudflare 1033`
- Erro local ao rodar o token antigo: `Unauthorized: Invalid tunnel secret`

## Bloqueio real

O host nao possui `cert.pem` em `~/.cloudflared`, e o token `CLOUDFLARED_TOKEN` local esta invalido.

O conector/API disponivel nesta sessao permitiu ler zona, DNS e tunnel, mas nao permitiu obter um novo token do endpoint:

```text
GET /accounts/{account_id}/cfd_tunnel/{tunnel_id}/token
```

A API retornou `Authentication error`, consistente com permissao insuficiente.

## Permissoes necessarias

Segundo a documentacao oficial da Cloudflare para tunnel tokens, o token de API precisa de pelo menos uma destas permissoes:

- `Cloudflare One Connectors Write`
- `Cloudflare One Connector: cloudflared Write`
- `Cloudflare Tunnel Write`

Referencia: https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/

## Caminho manual pelo dashboard

1. Acesse Cloudflare Zero Trust.
2. Va em `Networks > Tunnels`.
3. Abra o tunnel `valley-admin`.
4. Clique em `Add a replica`.
5. Copie o comando de instalacao gerado.
6. Extraia somente o token que aparece depois de `--token`.
7. Grave localmente, sem commitar:

```powershell
$env:CLOUDFLARED_TOKEN='<TOKEN_NOVO>'
```

8. Rode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\start_valley_admin_public.ps1 -BindHost 127.0.0.1 -AdminPort 8085 -PublicBaseUrl https://admin.brasildesconto.com.br
```

## Caminho automatico com API token correto

Quando existir um `CLOUDFLARE_API_TOKEN` ou `CF_API_TOKEN` com permissao de escrita de tunnel, rode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\repair_valley_cloudflare_named_tunnel.ps1 -StartAfterRepair
```

O script:

- consulta o tunnel `valley-admin`;
- obtem novo token remoto;
- grava o token fora do Git em `tmp/runtime/valley-cloudflare-named-tunnel.env`;
- sobe `scripts/start_valley_admin_public.ps1`;
- valida o dominio fixo.

## Fallback operacional atual

Enquanto o token do named tunnel nao for renovado, o acesso funcional permanece:

```text
http://100.109.240.100:8085/product
```

Esse fallback exige que o aparelho esteja conectado ao Tailscale.
