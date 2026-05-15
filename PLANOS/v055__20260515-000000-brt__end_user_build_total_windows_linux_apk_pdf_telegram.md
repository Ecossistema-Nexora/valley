PROPOSITO: Executar uma entrega END-USER-BUILD total para Windows, Linux, Android, PDF e Telegram.
CONTEXTO: O usuario reforcou que a entrega deve cobrir arquivo Windows, Linux, APK, PDF atualizado com todos os links e encaminhamento via Telegram.
REGRAS: Usar release mode, remover ferramentas de debug, validar links publicos e enviar por Telegram; quando exceder o limite do Bot, enviar link direto com SHA256.

# v055 - END-USER-BUILD Total Windows Linux APK PDF Telegram

## Checklist

- [x] Validar politica END-USER-BUILD e ausencia de UI tecnica.
- [ ] Executar build web em modo producao.
- [ ] Executar build Android APK split release.
- [ ] Executar build Windows e Linux com artefatos finais.
- [ ] Atualizar PDF com links da release.
- [ ] Encaminhar artefatos finais pelo Telegram, usando link publico quando necessario.
- [ ] Validar links publicos, release gate e rotina Gemini.

## Comando Canonico

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode release-final -Version v055
```

## Artefatos Esperados

- `admin/downloads/v055/Valley-ERP.exe`
- `admin/downloads/v055/Valley-ERP-Linux.run`
- `admin/downloads/v055/app-arm64-v8a-release.apk`
- `admin/downloads/v055/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf`

## Protocolo Telegram

- Enviar arquivos dentro do limite seguro como documento.
- Enviar arquivos grandes como link publico direto com SHA256.
