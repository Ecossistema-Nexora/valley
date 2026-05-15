PROPOSITO: Registrar a regra persistente para execucao sem pop-up de terminais no Windows.
CONTEXTO: Processos como Cloudflare Tunnel, Python API, SSH tunnel, PowerShell watchdogs e bridges devem rodar sem abrir consoles visiveis.
REGRAS: Terminais de servico usam launcher oculto; browsers, testes visuais e instrumentacao interativa podem abrir janelas quando necessario.

# Windows Sem Pop-up de Terminais

## Regra Mandatoria

Todo processo de servico iniciado por scripts do Valley no Windows deve ser aberto com:

- `CreateNoWindow = true`
- `WindowStyle = Hidden`
- stdout/stderr gravados em `tmp/runtime`
- sem janela `cmd`, `powershell`, `python`, `ssh`, `cloudflared` ou similar aparecendo para o usuario

## Excecoes Permitidas

As seguintes janelas podem abrir quando fizerem parte de validacao, teste ou uso interativo:

- browser
- Playwright visual ou outra instrumentacao com UI
- emulador Android
- instalador com interface grafica quando solicitado
- ferramenta interativa que o usuario precise controlar

## Launcher Padrao

Use `scripts/valley_hidden_process.ps1` e a funcao `Start-ValleyHiddenProcess` para processos longos.

Exemplo:

```powershell
. "$PSScriptRoot\valley_hidden_process.ps1"
Start-ValleyHiddenProcess `
  -FilePath $Cloudflared `
  -ArgumentList @('tunnel', 'run', '--token', $env:CLOUDFLARED_TOKEN) `
  -WorkingDirectory $RepoRoot `
  -StdoutLog $CloudflareStdoutLog `
  -StderrLog $CloudflareStderrLog
```

## Docker

Quando a execucao estiver em Docker, preferir `docker compose up -d` ou containers detached. O terminal interativo so deve ser usado para diagnostico manual.
