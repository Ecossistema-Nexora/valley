<!--
PROPOSITO: Documentar status e reparo seguro das integracoes de dropshipping Valley.
CONTEXTO: Este guia consolida provedores como Amazon, Alibaba, Shopee, AliExpress, CJDropshipping, Magalu e Mercado Livre.
REGRAS: Exibir apenas status sanitizado e nunca gravar tokens, senhas ou segredos no repositorio.
-->

# Status e reparo das integracoes de dropshipping

Use este comando para consolidar Amazon, Alibaba, Shopee, AliExpress,
CJDropshipping, Magalu e Mercado Livre no runtime local seguro:

```powershell
python scripts/repair_dropshipping_integrations.py
```

O resultado fica em:

```text
tmp/runtime/valley-dropshipping-integration-status.json
```

O arquivo de status e sanitizado: mostra presenca de token, login operacional,
flags de sincronizacao e pendencias, mas nao mostra segredo.

## Status possiveis

- `active`: existe token/API suficiente para operacao automatizada.
- `operator_login_ready`: existe login/senha local, mas ainda falta OAuth/API
  oficial para producao.
- `external_auth_pending`: falta token, consentimento OAuth, credencial de app
  ou aprovacao no provedor externo.

## Limites automaticos

O reparador resolve configuracao local, runtime, referencias de segredo e flags
seguras. Ele nao consegue concluir sozinho 2FA, consentimento OAuth, aprovacao
de app, liberacao comercial do marketplace ou rotacao da senha dentro do site
do provedor.
