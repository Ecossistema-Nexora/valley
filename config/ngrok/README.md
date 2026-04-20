# Valley ngrok Release Profile

Este diretorio concentra a malha de acesso externo do projeto Valley sem depender de arquivos globais do sistema operacional.

## Onboarding rapido

- Use `config/VALLEY_FIRST_CONNECTION_CHECKLIST.md` para a primeira conexao.
- O checklist cobre URL dinamica, URL permanente com `VALLEY_NGROK_ADMIN_DOMAIN` e a regra de nao expor segredo no repo.

## Estado validado neste host

- `ngrok` encontrado via `Get-Command ngrok`
- versao validada: `3.37.3`
- configuracao global detectada em `%LOCALAPPDATA%\\ngrok\\ngrok.yml`
- `VALLEY_NGROK_ADMIN_DOMAIN` ainda nao esta exportada no ambiente

## Arquivos versionados

- `valley-ngrok.yml`: tunnel nomeado para publicar o painel admin em `127.0.0.1:8080`
- `valley-ngrok.release.example.yml`: exemplo de release com dominio reservado
- `valley-public-endpoints.json`: inventario dos endpoints externos permanentes
- `bootstrap-ngrok.ps1`: verificador idempotente de instalacao e bootstrap local

## Uso dinamico

1. Suba o painel local em `127.0.0.1:8080`
2. Inicie o tunnel nomeado com a configuracao versionada
3. Consulte a URL publica pelo inspetor local em `127.0.0.1:4040`

Comandos:

```powershell
python scripts/serve_valley_admin.py --port 8080
powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1
python scripts/show_valley_public_urls.py
```

## Uso permanente para release

1. Reserve um dominio na conta ngrok, por exemplo `valley-admin-release.ngrok.app`
2. Exporte `VALLEY_NGROK_ADMIN_DOMAIN` com o dominio reservado
3. Inicie o launcher atual ou replique o dominio no template `valley-ngrok.release.example.yml`
4. Valide os endpoints descritos em `valley-public-endpoints.json`

Comandos:

```powershell
$env:VALLEY_NGROK_ADMIN_DOMAIN = "valley-admin-release.ngrok.app"
powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1
python scripts/show_valley_public_urls.py
```

## Bootstrap local

```powershell
powershell -ExecutionPolicy Bypass -File config/ngrok/bootstrap-ngrok.ps1
```

Se `ngrok` estiver ausente:

```powershell
powershell -ExecutionPolicy Bypass -File config/ngrok/bootstrap-ngrok.ps1 -InstallIfMissing
```

## Regra de seguranca

O `authtoken` continua fora do repositorio. O workspace versiona apenas a topologia do tunnel e os endpoints esperados.
