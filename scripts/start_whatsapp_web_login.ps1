# PROPOSITO: Automatizar start whatsapp web login no workspace Valley.
# CONTEXTO: Este script apoia operacao local, release, runtime ou manutencao ligada ao caminho scripts/start_whatsapp_web_login.ps1.
# REGRAS: Nao expor segredos, manter execucao idempotente e validar impactos antes de alterar recursos externos.

param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $root

python scripts/valley_communication_bridge.py whatsapp-login
