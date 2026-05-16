# Valley - Gemini Refactor Checklist

- Gerado em UTC: `2026-05-16T06:12:35Z`
- Arquivos varridos: `1374`
- Pendencias: `2`
- Digest: `39cef0c8a24ae1c88137538ed864050328a3686d95653da18c3ba132b4867715`

## Regras

- Nao apagar arquivos.
- Nao mover arquivos sem atualizar referencias e validar imports.
- Todo arquivo novo orientador deve conter `PROPOSITO:`, `CONTEXTO:` e `REGRAS:`.
- Ao terminar cada lote, deixar as alteracoes no workspace para aceitacao automatica por revarredura.

## Checklist

- [ ] 1. `structured_header_missing` em `scripts/create_valley_windows_exe_installer.ps1` - Headers ausentes: PROPOSITO:, CONTEXTO:, REGRAS: Acao: Adicionar comentario/header no formato correto do arquivo com PROPOSITO, CONTEXTO e REGRAS.
- [ ] 2. `structured_header_missing` em `scripts/install_valley_windows_bundle.ps1` - Headers ausentes: PROPOSITO:, CONTEXTO:, REGRAS: Acao: Adicionar comentario/header no formato correto do arquivo com PROPOSITO, CONTEXTO e REGRAS.
