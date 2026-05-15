PROPOSITO: Tornar END-USER-BUILD uma regra mandatoria e persistente de build final para usuario.
CONTEXTO: O usuario determinou que o termo acione modo producao, remocao de UI tecnica, ignorar dev_dependencies e priorizar APIs finais.
REGRAS: Sempre executar a validacao END-USER-BUILD ao invocar o termo, usar release mode e manter mock/bundle apenas como contingencia.

# v053 - END-USER-BUILD Mandatorio

## Checklist

- [x] Criar politica persistente `config/build/end-user-build.policy.json`.
- [x] Criar comando executavel `scripts/invoke_end_user_build.ps1`.
- [x] Registrar runbook em `docs/runtime/end-user-build.md`.
- [x] Persistir o gatilho em `.codex/config.toml`, `.cursor/rules/design.mdc`, VS Code tasks e politica de design.
- [x] Ajustar Flutter para `VALLEY_END_USER_BUILD=true` priorizar APIs finais em vez de bundle/mock primario.
- [x] Validar script, automacao mandataria, headers Gemini e release gate publico.

## Comando Canonico

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\invoke_end_user_build.ps1 -Mode validate
```

## Flags De Build

```text
--release
--dart-define=VALLEY_END_USER_BUILD=true
--dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br
```

## Criterios De Aceite

- `END-USER-BUILD` esta documentado como palavra-chave mandataria.
- UI final nao pode exibir banner debug, console de log, inspector ou botao flutuante tecnico.
- Builds finais usam APIs finais como fonte primaria.
- A rotina Valley Module Automation e acionada apos a mudanca.
