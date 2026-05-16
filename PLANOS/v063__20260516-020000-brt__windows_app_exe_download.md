<!--
PROPOSITO: Registrar a geracao do aplicativo Windows Valley em formato EXE unico.
CONTEXTO: O usuario solicitou o aplicativo Windows no formato exe e link para download.
REGRAS: Entregar um EXE baixavel que preserve as dependencias do build Flutter Windows.
-->

# v063 - Windows App EXE Download

## Resumo

Converter a entrega Windows validada em um arquivo `.exe` baixavel. Como o executavel Flutter depende de DLLs e da pasta `data`, a entrega em `.exe` deve ser um pacote instalador/autoextrator contendo o bundle completo, com politica de inicio automatico e atalhos.

## Checklist

- [x] Confirmar build Windows release existente.
- [x] Confirmar ferramenta local para empacotar `.exe`.
- [x] Aplicar politica de inicio automatico e atalho no Menu Iniciar.
- [x] Aplicar politica de atalho/fixacao na barra de tarefas.
- [x] Gerar pacote `.exe` unico.
- [x] Validar existencia, tamanho e hash SHA-256 do `.exe`.
- [x] Atualizar `PLANOS/STATUS_ATUAL.md` e `PLANOS/INDEX.md`.
- [x] Entregar link local de download no chat.

## Evidencias

- Build Windows release base: `frontend/flutter/build/windows/x64/runner/Release/valley_super_app.exe`.
- Bundle ZIP validado: `output/releases/valley_super_app_windows_v060_20260516_0155_brt.zip`.
- Ferramenta local encontrada: `C:\Windows\System32\iexpress.exe`.
- Instalador aplica:
  - instalacao em `%LOCALAPPDATA%\Valley\ValleySuperApp`;
  - atalho no Menu Iniciar;
  - atalho em Startup para inicio automatico;
  - atalho na barra de tarefas e tentativa de fixacao via Shell.Application;
  - abertura automatica do app ao fim da instalacao.
- EXE gerado: `output/releases/ValleySuperAppSetup_v060_20260516_0205_brt.exe`.
- Tamanho do EXE: 15.092.224 bytes.
- SHA-256: `57181C08E49633A65CFE72295D4BB07F14E7613DB68931457394FFACAB8CE323`.
- Validacao de instalacao com `/NoLaunch`:
  - app instalado em `%LOCALAPPDATA%\Valley\ValleySuperApp`;
  - atalho no Menu Iniciar criado;
  - atalho de inicio automatico criado;
  - atalho no diretorio de barra de tarefas criado;
  - fixacao por Shell verb tentada, mas nao confirmada pelo Windows.

## Bloqueios

- Nenhum bloqueio ativo.

## Proxima Acao

Atividade concluida. Entregar o link local do EXE no chat.
