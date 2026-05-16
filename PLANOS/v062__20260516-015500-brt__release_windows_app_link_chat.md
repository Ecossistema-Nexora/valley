<!--
PROPOSITO: Registrar a entrega do aplicativo Windows Valley com link local no chat.
CONTEXTO: O usuario solicitou gerar o aplicativo Windows e entregar o link aqui no chat.
REGRAS: Produzir build release, empacotar dependencias do runner e validar o artefato antes de entregar.
-->

# v062 - Release Windows App Link Chat

## Resumo

Gerar o aplicativo Windows Valley em modo release, empacotar o diretorio `runner/Release` com dependencias e entregar um link local direto do ZIP no chat.

## Checklist

- [x] Limpar processos residuais do build Android interrompido.
- [x] Gerar build Windows release com API final.
- [x] Persistir regra de atualizacao de status a cada 5 minutos.
- [x] Empacotar o aplicativo Windows em `output/releases`.
- [x] Validar executavel, ZIP e hash SHA-256.
- [x] Entregar link local do artefato no chat.

## Evidencias

- Build Windows release concluido em 2026-05-16.
- Executavel gerado em `frontend/flutter/build/windows/x64/runner/Release/valley_super_app.exe`.
- Log persistido em `tmp/runtime/flutter-windows-v060-release.stdout.log`.
- Pacote gerado em `output/releases/valley_super_app_windows_v060_20260516_0155_brt.zip`.
- ZIP validado com 15.356.180 bytes, 29 entradas, `valley_super_app.exe` e `data/`.
- SHA-256: `A6153B73F4C1966C6C8DBDCE0988A75B1FB17A90E8339E2EF0064153820B5A19`.

## Bloqueios

- Nenhum bloqueio ativo.

## Proxima Acao

Atividade concluida. Entregar link local no chat.
