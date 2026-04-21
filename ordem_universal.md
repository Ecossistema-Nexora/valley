# Ordem Universal - WhatsApp/Bridge

Arquivo de fila para ordens recebidas via WhatsApp ou ponte universal.

Entradas novas devem seguir o formato:

```yaml
---
source: whatsapp
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
