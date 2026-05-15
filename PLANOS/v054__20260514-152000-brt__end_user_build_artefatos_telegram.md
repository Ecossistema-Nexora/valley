PROPOSITO: Ampliar END-USER-BUILD para gerar e entregar todos os artefatos finais Valley.
CONTEXTO: O usuario determinou que o termo afete Windows, Linux, Android, paineis web, PDF atualizado e reenvio Telegram sempre de forma mandatoria.
REGRAS: A esteira completa deve usar release-final, atualizar web/PDF, gerar executaveis e APK, e enviar artefatos finais pelo Telegram.

# v054 - END-USER-BUILD Artefatos E Telegram

## Checklist

- [x] Alterar o comando canonico para `scripts\invoke_end_user_build.ps1 -Mode release-final`.
- [x] Ampliar a politica `config/build/end-user-build.policy.json` com artefatos obrigatorios.
- [x] Ampliar o script `invoke_end_user_build.ps1` para web, APK Android, Windows, Linux, PDF e Telegram.
- [x] Atualizar `publish_valley_product_web.ps1` para build web END-USER-BUILD com dart defines finais.
- [x] Atualizar runbook, Codex config, Cursor rule, VS Code tasks e politica de design.
- [x] Validar sintaxe, JSON, rotina Gemini e release gate publico.

## Comando Canonico

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode release-final
```

## Artefatos Obrigatorios

- Painel web publicado em `admin/product`.
- APK Android em `admin/downloads/<versao>/app-arm64-v8a-release.apk`.
- Windows em `admin/downloads/<versao>/Valley-ERP.exe`.
- Linux em `admin/downloads/<versao>/Valley-ERP-Linux.run`.
- PDF atualizado em `admin/downloads/<versao>/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf`.
- Reenvio Telegram dos artefatos finais.

## Criterios De Aceite

- O termo `END-USER-BUILD` dispara a esteira `release-final`.
- Todos os builds usam `--release` e `VALLEY_END_USER_BUILD=true`.
- O PDF e o Telegram deixam de ser etapa opcional no modo final.

## Evidencia De Fechamento

- Web publicada em `admin/product` com `VALLEY_END_USER_BUILD=true`.
- Android split release gerado em `admin/downloads/v054/app-arm64-v8a-release.apk`.
- Windows gerado em `admin/downloads/v054/Valley-ERP.exe`.
- Linux gerado em `admin/downloads/v054/Valley-ERP-Linux.run`.
- PDF atualizado em `admin/downloads/v054/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf`.
- Telegram concluido: APK, PDF e Linux como documentos; Windows como link publico com SHA256 por exceder o limite seguro de upload do Bot.
- Links publicos v054 verificados com HTTP 200.
- Gate publico `validate_valley_release_gate.py` concluido com `25/25` checks e `0` falhas.
- Rotina Gemini/watchdog concluida com `pending_total=0`.
