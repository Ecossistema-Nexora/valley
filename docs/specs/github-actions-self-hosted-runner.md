# GitHub Actions Self-Hosted Runner

Provisionamento local do runner Windows para `Ecossistema-Nexora/valley`.

## Segredo

- Use apenas `GITHUB_RUNNER_TOKEN` local.
- Nunca cole o token em arquivo versionado.
- O token de registro do runner e efêmero e deve ser regenerado no GitHub quando expirar ou for exposto.

## Arquivo de apoio

- Script: [setup_github_actions_runner.ps1](/C:/Users/ereta/.codex/worktrees/VALLEY/scripts/setup_github_actions_runner.ps1)

## Exemplo rapido

```powershell
$env:GITHUB_RUNNER_TOKEN='SEU_TOKEN_LOCAL'
powershell -ExecutionPolicy Bypass -File scripts/setup_github_actions_runner.ps1 -Configure -InstallService
```

## Iniciar serviço

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_github_actions_runner.ps1 -StartRunner
```

## Personalizar nome e labels

```powershell
$env:GITHUB_RUNNER_TOKEN='SEU_TOKEN_LOCAL'
powershell -ExecutionPolicy Bypass -File scripts/setup_github_actions_runner.ps1 `
  -Configure `
  -RunnerName 'valley-windows-01' `
  -RunnerLabels 'self-hosted,windows,valley,flutter'
```

## Workflow

```yaml
runs-on: self-hosted
```
