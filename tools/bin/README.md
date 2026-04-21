# Valley local tool shims

Esta pasta contem wrappers versionados para ferramentas que podem nao estar instaladas no PATH do Windows.

- `psql.cmd` delega para o `psql` dentro do servico `postgres` do Docker Compose e converte arquivos locais (`-f`) para `stdin` quando necessario.
- `mongosh.cmd` delega para o `mongosh` dentro do servico `mongodb` do Docker Compose e converte arquivos locais (`--file`) para `/dev/stdin` quando necessario.

O orquestrador `scripts/valley_db_orchestrator.py` prioriza `tools/bin` antes do PATH global, mantendo a esteira reproduzivel sem exigir instalacao global dessas CLIs.
