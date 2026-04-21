# Ordem Telegram - Valley

Arquivo de fila para ordens recebidas via Telegram.

Entradas novas devem seguir o formato:

```yaml
---
source: telegram
kind: status
status: pending
priority: normal
codex_route: inbox
received_at_utc: 2026-04-20T00:00:00Z
auto_approval: safe_only
---
Texto livre da ordem.
```

Nenhuma ordem pendente registrada neste bootstrap.

---
source: telegram
kind: queue_triage
status: accepted
priority: normal
codex_route: auto_start
execution_gate: safe_only
received_at_utc: 2026-04-20T12:48:37Z
auto_approval: safe_only
---
Implemente todas as regras para a Helena
