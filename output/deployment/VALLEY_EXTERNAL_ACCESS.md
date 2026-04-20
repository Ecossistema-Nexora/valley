# Valley External Access

Este runbook publica o painel `admin/` para testes externos fora da rede local usando `ngrok`, com trilha separada para URL dinamica e URL permanente de release.

## Entrada rapida

- Checklist de primeira conexao: `config/VALLEY_FIRST_CONNECTION_CHECKLIST.md`
- Esse checklist resume OAuth MCP, diferenca entre conectores do workspace e da plataforma, e ativacao da URL permanente sem gravar segredo no repositorio.

## Estado atual do host

- `ngrok` validado no host em `2026-04-20`
- versao detectada: `3.37.3`
- instalacao encontrada via WinGet
- configuracao global do `ngrok` detectada fora do repositorio
- `VALLEY_NGROK_ADMIN_DOMAIN` ainda nao esta exportada no ambiente atual

## Componentes versionados no workspace

- tunnel dinamico: `config/ngrok/valley-ngrok.yml`
- template de release com dominio reservado: `config/ngrok/valley-ngrok.release.example.yml`
- inventario dos endpoints permanentes: `config/ngrok/valley-public-endpoints.json`
- bootstrap local do `ngrok`: `config/ngrok/bootstrap-ngrok.ps1`
- launcher operacional: `powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1`
- descoberta dos endpoints ativos: `python scripts/show_valley_public_urls.py`

## URLs externas

- URL dinamica: o launcher inicia `valley-admin` com o tunnel nomeado e expoe o painel em HTTPS para testes externos imediatos.
- URL permanente: defina `VALLEY_NGROK_ADMIN_DOMAIN` com um dominio reservado da sua conta `ngrok`.
- Sem dominio reservado, o acesso externo continua funcional, mas a URL publica muda em reinicios.

## Endpoints permanentes esperados

Com `VALLEY_NGROK_ADMIN_DOMAIN` definido, a malha publica fica:

- dashboard: `https://${VALLEY_NGROK_ADMIN_DOMAIN}/`
- healthcheck: `https://${VALLEY_NGROK_ADMIN_DOMAIN}/healthz`
- payload admin: `https://${VALLEY_NGROK_ADMIN_DOMAIN}/api/admin-data`

Esses endpoints tambem estao versionados em `config/ngrok/valley-public-endpoints.json`.

## Fluxo dinamico recomendado

1. Regenerar o payload do painel:
   `python scripts/valley_admin_builder.py build`
2. Subir o servidor HTTP do admin:
   `python scripts/serve_valley_admin.py --port 8080`
3. Subir o tunnel nomeado:
   `powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1`
4. Ler as URLs publicas:
   `python scripts/show_valley_public_urls.py`

## Fluxo permanente de release

1. Reservar um dominio na conta `ngrok`, por exemplo `valley-admin-release.ngrok.app`
2. Exportar a variavel:
   `$env:VALLEY_NGROK_ADMIN_DOMAIN = "valley-admin-release.ngrok.app"`
3. Subir o launcher:
   `powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1`
4. Validar os endpoints de `config/ngrok/valley-public-endpoints.json`

## Endpoints locais importantes

- UI: `http://127.0.0.1:8080/`
- Health: `http://127.0.0.1:8080/healthz`
- JSON: `http://127.0.0.1:8080/api/admin-data`

## Observacao operacional

- O `authtoken` permanece fora do repositorio.
- O workspace agora versiona a topologia do tunnel, o template de dominio reservado e o inventario das URLs permanentes.
- "Permanente" aqui significa dominio reservado na conta `ngrok`; sem essa reserva, o repositório entrega apenas a preparacao completa para a exposicao estavel.
