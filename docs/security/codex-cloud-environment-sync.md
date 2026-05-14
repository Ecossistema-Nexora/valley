<!--
PROPOSITO: Descrever a sincronizacao segura do ambiente Codex Cloud para o Valley.
CONTEXTO: Este guia usa scripts locais para materializar env, setup script e secrets em runtime privado.
REGRAS: Manter secrets fora do Git e usar tmp/runtime como area local nao versionada.
-->

# Sincronizacao do ambiente Codex Cloud

O script de execucao unica para Windows e:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/sync_codex_cloud_environment.ps1
```

Ele usa `tmp/runtime/codex-cloud-secrets.env` como fonte, gera
`tmp/runtime/codex-cloud-setup.sh`, copia o env completo para o clipboard e abre
`https://chatgpt.com/codex/settings` com um painel auxiliar no navegador.

## Setup script do Codex Cloud

Use o conteudo de `tmp/runtime/codex-cloud-setup.sh` no campo de setup script do
ambiente:

```bash
python scripts/materialize_codex_cloud_env.py
python scripts/repair_dropshipping_integrations.py
```

`materialize_codex_cloud_env.py` roda durante a fase de setup, quando os secrets
do Codex Cloud ainda estao disponiveis, e grava `.env`/`tmp/runtime` para a
automacao Valley sem versionar valores.

## Observacao

A documentacao oficial do Codex Cloud descreve a configuracao de environments
em `chatgpt.com/codex/settings`. Ate o momento nao ha comando publico do Codex
CLI para gravar secrets de environment diretamente, entao o script usa automacao
por navegador e clipboard local.
