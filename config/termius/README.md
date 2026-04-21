# Termius SSH Runbook

Runbook operacional para acesso externo ao ambiente Valley via Termius sem expor a porta `22` diretamente na internet.

## Objetivo

Permitir administração remota por SSH com a menor superfície de ataque possível.

Ordem de preferência:

1. Cloudflare Tunnel com SSH/TCP protegido por Access.
2. Tailscale ou ZeroTier com IP de malha privada.
3. ngrok TCP apenas para uso temporario e controlado.
4. VPN tradicional com SSH apenas na rede privada.

Evitar:

- abrir `22/tcp` em firewall publico;
- publicar SSH em IP publico sem MFA, allowlist ou tunelamento;
- gravar segredos operacionais no repositorio.

## Premissas

- Termius e um cliente SSH, nao o endpoint.
- O servidor alvo ja precisa aceitar SSH localmente.
- O acesso externo deve apontar para um endereco privado, um endpoint de tunel ou um IP de malha.
- A conta usada no servidor deve ser minima e auditavel.

## Variaveis e segredos fora do repo

Manter fora do controle de versao:

- chave privada SSH do operador;
- chave publica correspondente em `authorized_keys`;
- `cloudflared` credentials / token;
- `tailscale` auth key ou login state;
- `zerotier` network ID e autorizacao do nodo;
- `ngrok` authtoken;
- nome do host, usuario e porta do SSH se forem ambientes sensiveis;
- qualquer bastion password, recovery code ou secret de MFA.

Sugestao de armazenamento:

- Windows Credential Manager;
- gerenciador de senhas corporativo;
- variaveis de ambiente locais nao versionadas;
- arquivos de configuracao locais fora do repo.

## Requisitos minimos do host remoto

- SSH habilitado e testado em `localhost` ou na interface privada.
- Usuario sem privilegio root direto para uso diario.
- `sudo` apenas quando necessario.
- Chave SSH com senha, se a politica permitir.
- Firewall aceitando conexao apenas do tunel, da malha privada ou da VPN.
- Registro de auditoria habilitado no host.

## Opcao 1: Cloudflare Tunnel

Use quando o host precisa ficar acessivel sem IP publico aberto.

Topologia:

- `Termius -> Cloudflare Access / Tunnel -> sshd local`

Fluxo recomendado:

1. Suba `cloudflared` no host.
2. Publique um hostname privado via Tunnel.
3. Proteja o acesso com Access, MFA e policy de identidade.
4. No Termius, aponte para o hostname do endpoint protegido ou use o fluxo SSH suportado pela sua politica de Access.

Checklist de implantacao:

- `sshd` ativo no host;
- `cloudflared` autenticado localmente;
- hostname configurado para o tunnel;
- policy de Access aplicada;
- `22/tcp` nao exposto ao publico;
- teste de login com chave valido.

Validacao:

- o hostname resolve e aceita a politica de acesso;
- a conexao SSH autentica com a chave esperada;
- o IP publico do host nao precisa aceitar entrada direta.

Rollback:

- remover a rota do hostname;
- revogar a policy de Access;
- parar `cloudflared`;
- restaurar firewall para negar entrada publica.

## Opcao 2: Tailscale ou ZeroTier

Use quando o objetivo e operar como se o host estivesse na mesma LAN.

Topologia:

- `Termius -> IP da malha privada -> sshd`

Checklist de implantacao:

- o host entrou na malha;
- o IP privado foi registrado;
- o firewall aceita SSH somente da subrede da malha;
- a chave SSH do operador esta instalada;
- o alias DNS interno, se existir, aponta para o IP da malha.

Validacao:

- conectar pelo IP da malha privada;
- confirmar que a rota nao depende de IP publico;
- confirmar que o SSH falha fora da malha.

Rollback:

- remover o host da malha;
- revogar a autorizacao do nodo;
- limpar a regra de firewall especifica;
- manter SSH inacessivel pela internet.

### Inicializacao Tailscale

Quando `TAILSCALE_AUTHKEY` estiver no `.env` local:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_termius_tailscale.ps1 -Hostname valley-codex -EnableSsh
```

Sem auth key, o comando abre o fluxo interativo de login do Tailscale:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_termius_tailscale.ps1 -Hostname valley-codex -EnableSsh
```

Depois, colete os dados para preencher no Termius:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/termius_tailscale_status.ps1
```

Para Docker/MCP e WSL2, use o runbook dedicado:

```text
config/termius/TAILSCALE_DOCKER_WSL.md
```

## Opcao 3: ngrok TCP

Use apenas para ponte temporaria, homologacao ou resgate operacional.

Topologia:

- `Termius -> endpoint TCP ngrok -> sshd local`

Checklist de implantacao:

- `ngrok` autenticado localmente;
- tunel TCP apontando para a porta interna do SSH;
- allowlist ou credencial forte no host;
- token de ngrok fora do repo.

Validacao:

- endpoint TCP responde no inspetor do tunel;
- login SSH funciona com a chave esperada;
- encerramento do tunnel remove a rota externa.

Rollback:

- encerrar o processo do tunnel;
- revogar o token;
- remover qualquer host public DNS temporario;
- confirmar que nao sobrou porta publica exposta.

## Opcao 4: VPN tradicional

Use quando a organizacao ja padroniza acesso por rede privada.

Topologia:

- `Termius -> VPN corporativa -> sshd`

Checklist de implantacao:

- VPN conectada;
- rota do host visivel na rede privada;
- firewall aceitando SSH apenas da VPN;
- chave SSH em vigor.

Validacao:

- SSH conecta somente dentro da VPN;
- fora da VPN a porta permanece inacessivel.

Rollback:

- desconectar a VPN;
- remover a rota interna do host se necessario;
- manter o firewall bloqueando entrada publica.

## Checklist de implantacao

1. Confirmar que o host remoto esta alcançavel por uma das opcoes acima.
2. Confirmar que a porta publica `22` nao esta exposta ao mundo.
3. Confirmar que a chave publica do operador esta instalada.
4. Confirmar que o usuario remoto tem permissao minima.
5. Confirmar que o segredo do tunnel ou da malha nao esta no repo.
6. Confirmar que o fluxo de rollback esta documentado e executavel.

## Checklist de validacao

- login via Termius com a chave correta;
- `whoami` retorna o usuario esperado;
- `sudo -l` mostra apenas o necessario;
- conexao cai quando o tunnel ou a malha e desligado;
- nenhum segredo foi escrito em arquivos versionados.

## Checklist de rollback

- parar o tunnel, a VPN ou o agente da malha;
- revogar token ou autorizacao temporaria;
- remover DNS temporario ou hostname publico;
- invalidar chaves de teste, se usadas;
- verificar que o host nao aceita SSH publico direto.

## Comando auxiliar local

Use o verificador nao destrutivo para inspecionar prerequisitos do host de operacao:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/termius_prereq_check.ps1
```

## Inicializacao assistida

Cloudflare Tunnel, quando `CLOUDFLARED_TOKEN` estiver definido no ambiente local:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_termius_cloudflare_tunnel.ps1
```

Cloudflare quick tunnel para SSH, sem token, indicado apenas para validacao temporaria:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_termius_cloudflare_quick_ssh.ps1 -LocalPort 22
```

ngrok TCP temporario, quando `VALLEY_NGROK_AUTHTOKEN` estiver definido no ambiente local:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_termius_ngrok_tcp.ps1 -LocalPort 22
```

Template de Cloudflare Tunnel:

```text
config/termius/cloudflared-tunnel.example.yml
```
