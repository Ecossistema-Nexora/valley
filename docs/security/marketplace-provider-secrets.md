# Credenciais de fornecedores e marketplaces

Este projeto nao deve versionar login, senha, token OAuth, client secret ou refresh token.
As credenciais operacionais de Amazon, Alibaba e Shopee entram apenas por `.env`
local, variaveis protegidas de CI/CD ou secret manager.

## Variaveis aceitas

Use credencial compartilhada quando os tres provedores usam o mesmo operador:

```env
VALLEY_SUPPLIER_SHARED_USER=
VALLEY_SUPPLIER_SHARED_PASSWORD=
```

Use credenciais especificas quando um provedor mudar:

```env
AMAZON_USER=
AMAZON_PASSWORD=
ALIBABA_USER=
ALIBABA_PASSWORD=
SHOPEE_USER=
SHOPEE_PASSWORD=
```

`SHOPPE_USER` e `SHOPPE_PASSWORD` sao aceitos como alias de compatibilidade,
mas o nome correto no projeto e `SHOPEE_*`.

## Bootstrap local

O comando abaixo le `.env` e grava somente em `tmp/runtime`, que ja e ignorado
pelo Git:

```powershell
python scripts/bootstrap_supplier_credentials.py
```

Para validar sem gravar:

```powershell
python scripts/bootstrap_supplier_credentials.py --dry-run
```

O script nao imprime valores sensiveis. Ele apenas informa quais provedores
foram configurados ou ficaram pendentes.

## Regra de producao

Login e senha pessoal servem apenas para operacao local controlada. Para
producao, cada provedor deve migrar para OAuth, API oficial, token por app,
webhook assinado e secret manager com rotacao individual.
