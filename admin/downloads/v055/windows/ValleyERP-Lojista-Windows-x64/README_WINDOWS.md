PROPOSITO: Instalar o Valley ERP Lojista no Windows.
CONTEXTO: Pacote desktop v055 gerado a partir do Flutter Desktop com login inicial do lojista e menu por botoes.
REGRAS: Use o instalador local sem permissao administrativa; os modulos nao exibem cabecalho global de links.

# Valley ERP Lojista - Windows x64

## Instalar

Use o instalador nativo principal da release:

``text
Valley-ERP.exe
``

O instalador nativo instala o ERP, registra a inicializacao automatica no Windows
e abre o aplicativo. Use Valley-ERP.exe --check para validar o pacote sem instalar
e Valley-ERP.exe --uninstall para remover a instalacao nativa.

## Executar sem instalar

``powershell
.\app\ValleyERP-Lojista.exe
``

## Remover

``powershell
.\uninstall-valley-erp-lojista-windows.ps1
``

API base embarcada: $ApiBaseUrl