param()

$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $root

npx --yes --package playwright node scripts/whatsapp_web_driver.js login
