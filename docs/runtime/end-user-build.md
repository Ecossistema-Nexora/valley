<!--
PROPOSITO: Documentar o comando mandatorio END-USER-BUILD para releases de interface Valley.
CONTEXTO: Este runbook associa a palavra-chave END-USER-BUILD ao modo final de producao para usuario.
REGRAS: Usar release mode, remover sinais de desenvolvimento e priorizar APIs finais em vez de mock/bundle primario.
-->

# END-USER-BUILD

## Regra Mandatoria

Sempre que o termo `END-USER-BUILD` for invocado, o Codex deve executar a esteira final completa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode release-final
```

Para checagem rapida sem gerar artefatos:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode validate
```

## Diretriz De Build

- Ambiente: `Production / Release Mode`.
- Limpeza: desativar `debugShowCheckedModeBanner`, `LogConsole`, `Inspector` e qualquer `FloatingActionButton` de suporte tecnico.
- Foco: renderizacao fiel ao design system oficial do Valley, mostrando somente contexto de uso final.
- Dados: usar APIs reais ou finais como fonte primaria. Bundle local pode existir apenas como fallback de contingencia.
- Entregas obrigatorias: paineis web, Android/APK, Windows `Valley-ERP.exe`, Linux `Valley-ERP-Linux.run`, PDF atualizado e reenvio Telegram.

## Instrucao Senior

Gere o codigo ignorando todas as bibliotecas de desenvolvimento (`dev_dependencies`). O output deve ser pronto para publicacao, focado exclusivamente na jornada do usuario final e na excelencia visual.

## Comandos De Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode build-web
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode build-apk
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode build-windows
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode build-desktop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode update-pdf
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode send-telegram
```

Todos os comandos de build usam:

```text
--release
--dart-define=VALLEY_END_USER_BUILD=true
--dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br
```
