param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $root

python scripts/valley_communication_bridge.py whatsapp-login
