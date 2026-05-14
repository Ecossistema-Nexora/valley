PROPOSITO: Instalar o Valley ERP Lojista no Windows.
CONTEXTO: Pacote desktop v047 gerado a partir do Flutter Desktop com login inicial do lojista e menu por botoes.
REGRAS: Use o instalador local sem permissao administrativa; os modulos nao exibem cabecalho global de links.

# Valley ERP Lojista - Windows x64

## Instalar

Abra PowerShell dentro desta pasta e execute:

``powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install-valley-erp-lojista-windows.ps1
``

## Executar sem instalar

``powershell
.\app\ValleyERP-Lojista.exe
``

## Remover

``powershell
.\uninstall-valley-erp-lojista-windows.ps1
``

API base embarcada: $ApiBaseUrl