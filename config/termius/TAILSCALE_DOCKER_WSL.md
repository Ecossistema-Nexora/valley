# Tailscale Docker, MCP e WSL2

## Docker / MCP

O `docker-compose.yml` inclui o servico `tailscale` nos profiles `tailscale` e `mcp`.

Uso:

```powershell
$env:TS_AUTHKEY='tskey-auth-...'
docker compose --profile tailscale up -d tailscale
docker compose exec -T tailscale tailscale ip -4
```

Ou pelo script local, carregando `.env`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_tailscale_docker.ps1
```

Preencha no `.env` local:

```text
TS_AUTHKEY=
TAILSCALE_API_KEY=
VALLEY_TAILSCALE_DOCKER_HOSTNAME=valley-mcp-docker
VALLEY_TAILSCALE_DOCKER_EXTRA_ARGS=--accept-routes
VALLEY_TAILSCALE_USERSPACE=false
```

Observacao:

- o container usa `/dev/net/tun` e `NET_ADMIN`. Em Docker Desktop, se o host negar TUN, altere `VALLEY_TAILSCALE_USERSPACE=true`, mas isso reduz capacidades de roteamento.
- `TAILSCALE_API_KEY` serve para automacao da API administrativa. Para `tailscale up` em Docker/WSL, o bootstrap ainda precisa de `TS_AUTHKEY` ou `TAILSCALE_AUTHKEY`.

## WSL2 / Linux

Uso:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_tailscale_wsl.ps1
```

Com distro explicita:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_tailscale_wsl.ps1 -Distro Ubuntu
```

Para manter a distro ativa e o IP do WSL online para Termius, rode tambem:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_tailscale_wsl_keepalive.ps1 -Distro Ubuntu
```

Preencha no `.env` local:

```text
TAILSCALE_AUTHKEY=
VALLEY_TAILSCALE_WSL_HOSTNAME=valley-wsl2
VALLEY_TAILSCALE_WSL_DISTRO=Ubuntu
VALLEY_TAILSCALE_WSL_USER=eretazan
```

Sem auth key, o comando `tailscale up` abre fluxo interativo de login.

O bootstrap `scripts/start_tailscale_wsl.ps1` executa o script Linux como `root`, ativa o `tailscaled` e garante `openssh-server`, para que o IP do WSL seja acessivel no Termius.

## Termius

Para acesso via Termius, use OpenSSH no destino e preencha:

```text
Host: <tailscale-ip>
Port: 22
Username: <usuario-linux-ou-windows>
Authentication: SSH key ou senha local
```

No Windows, `tailscale ssh` nativo nao substitui o OpenSSH Server. Use o IP Tailscale do host com o servico `sshd` ativo.
No WSL2, o IP fica online apenas enquanto a distro estiver iniciada. Se o Ubuntu parar, rode novamente `powershell -ExecutionPolicy Bypass -File scripts/start_tailscale_wsl.ps1 -Distro Ubuntu`.
