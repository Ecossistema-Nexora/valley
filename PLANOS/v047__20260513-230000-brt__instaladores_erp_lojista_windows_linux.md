PROPOSITO: Gerar artefatos instalaveis do ERP Lojista Valley para Windows e Linux.
CONTEXTO: O APK e PDF v044 ja foram enviados; a sequencia solicitada e iniciar os instaladores desktop do ERP Lojista com login inicial, menu por botoes e modulos sem cabecalho global de links.
REGRAS: Nao quebrar Android/web, usar Flutter Desktop quando possivel, manter login como primeira tela, navegar por botoes, nao exibir cabecalho de links nos modulos e versionar artefatos em `admin/downloads/v047`.

# v047 - Instaladores ERP Lojista Windows e Linux

## Resumo

- Criar entrypoint desktop dedicado para ERP Lojista.
- Habilitar plataformas desktop sem alterar o APK.
- Gerar build Windows x64 e instalador/portable.
- Preparar pacote Linux x64 e instalador shell; gerar binario Linux se o ambiente WSL suportar.
- Publicar manifestos, hashes e links em `admin/downloads/v047`.

## Checklist

- [x] Criar shell Flutter Desktop com login inicial do lojista.
- [x] Criar menu principal por botoes e telas de modulo sem cabecalho global de links.
- [x] Habilitar plataformas Windows/Linux no projeto Flutter.
- [x] Gerar build Windows x64 e pacote instalavel.
- [x] Preparar pacote/instalador Linux x64.
- [x] Gerar manifesto v047 com hashes e links publicos.
- [x] Validar artefatos e registrar planos abertos.

## Criterios De Aceite

- App desktop abre no login do lojista quando nao ha sessao.
- Login valido ou sessao local controlada leva ao menu principal em botoes.
- Cada botao abre uma tela de modulo funcional.
- Tela de modulo usa apenas botao de retorno ao menu; nao usa cabecalho de links.
- Artefatos Windows/Linux possuem hash e instrucao de instalacao.

## Proxima Acao

- Continuar pelos planos v045 e v046: PDV offline-first e privilegios/usuarios do ERP Lojista.

## Evidencias

- Entrypoint desktop: `frontend/flutter/lib/merchant_erp_desktop_main.dart`.
- Shell desktop: `frontend/flutter/lib/src/ui/merchant_erp_desktop_app.dart`.
- `flutter analyze --no-pub lib\merchant_erp_desktop_main.dart lib\src\ui\merchant_erp_desktop_app.dart`: sem issues.
- `flutter create --platforms=windows,linux .`: criou scaffolds desktop.
- `flutter build windows --release --target lib\merchant_erp_desktop_main.dart --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br`: gerou `frontend/flutter/build/windows/x64/runner/Release/valley_super_app.exe`; o alvo CMake `INSTALL` tentou gravar em `C:\Program Files\valley_super_app`, entao o pacote portable foi montado de forma controlada em `admin/downloads/v047/windows/ValleyERP-Lojista-Windows-x64`.
- Script duravel de pacote: `scripts/package_merchant_erp_desktop.ps1`.
- ZIP Windows publicado: `admin/downloads/v047/ValleyERP-Lojista-Windows-x64-v047.zip`.
- Instalador Windows dentro do pacote: `install-valley-erp-lojista-windows.ps1`.
- Pacote Linux publicado: `admin/downloads/v047/ValleyERP-Lojista-Linux-x64-v047.tar.gz`.
- Instalador Linux dentro do pacote: `install-valley-erp-lojista-linux.sh`; neste host Windows o WSL respondeu `ready`, mas nao encerrou limpo no tempo limite e reportou falha de sessao systemd, entao o pacote Linux segue com instalador e build-from-source para host Linux com Flutter Desktop.
- Manifesto publico: `https://admin.brasildesconto.com.br/downloads/v047/VALLEY_ERP_LOJISTA_DESKTOP_INSTALLERS_V047.json` retornou HTTP 200.
- ZIP Windows publico: `https://admin.brasildesconto.com.br/downloads/v047/ValleyERP-Lojista-Windows-x64-v047.zip` retornou HTTP 200.
- Pacote Linux publico: `https://admin.brasildesconto.com.br/downloads/v047/ValleyERP-Lojista-Linux-x64-v047.tar.gz` retornou HTTP 200.
- SHA256 Windows: `9FFCFFC307240593AF972E7BF526BCCAD2791ABC0B8545305CA9C9ED3CE3D8E5`.
- SHA256 Linux: `DEE4ADB8227DDD4CC3D46131E235287F4785648324F15BF14D451BEF8E417A98`.
