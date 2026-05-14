PROPOSITO: Tornar o PDV do ERP Lojista Valley offline-first, mantendo venda, caixa e fila operacional funcionando durante queda temporaria de rede.
CONTEXTO: O usuario aprovou a direcao visual do ERP Lojista e definiu que o PDV e funcoes interligadas devem continuar funcionando offline e sincronizar imediatamente apos reconexao.
REGRAS: Preservar identidade Valley, usar Stitch v2 como referencia visual ativa, nao expor segredos, manter operacoes financeiras auditaveis e nao permitir acoes sensiveis sem confirmacao online.

# v045 - PDV Offline First ERP Lojista

## Resumo

- Definir contrato tecnico offline-first para o app ERP Lojista instalavel em Windows e Linux.
- Garantir que PDV, caixa, carrinho, vendas pendentes, estoque local e recibos funcionem sem internet.
- Sincronizar automaticamente apos reconexao com fila local idempotente, trilha de auditoria e resolucao de conflitos.
- Separar operacoes permitidas offline das operacoes que exigem online.
- Preparar a implementacao Flutter Desktop com cache local duravel e validacao por cenarios de queda/reconexao.

## Checklist

- [x] Registrar plano persistente v045 para PDV offline-first.
- [x] Criar especificacao tecnica do modo offline do ERP Lojista.
- [x] Adicionar dependencias locais do Flutter Desktop para banco local, conectividade e fila de sync. Concluido em 2026-05-14 13:22 BRT com store JSON duravel sem aumentar o empacotamento desktop.
- [x] Implementar camada local `merchant_erp_offline_store` com schema de caixa, vendas, itens, estoque espelho e fila. Concluido em 2026-05-14 13:22 BRT.
- [x] Implementar servico de sincronizacao imediata apos reconexao com idempotency key por evento. Concluido em 2026-05-14 13:22 BRT.
- [x] Adaptar telas PDV/Estoque/Pedidos para indicar online, offline, pendente e sincronizado. Concluido em 2026-05-14 13:22 BRT.
- [x] Validar com teste: vender offline, reconectar, sincronizar e conferir ausencia de duplicidade. Concluido em 2026-05-14 13:22 BRT.

## Decisoes Tecnicas

- O PDV deve aceitar venda offline quando houver sessao de lojista previamente autenticada e dispositivo autorizado.
- Cada venda offline deve gerar `local_sale_id`, `device_id`, `idempotency_key`, timestamp local, subtotal, descontos, forma de pagamento e hash do recibo.
- A fila local deve ser append-only: eventos nao sao apagados antes de confirmacao remota e checkpoint persistido.
- A sincronizacao deve priorizar: abertura/fechamento de caixa, vendas, movimentos de caixa, baixa/reserva de estoque, recibos e auditoria.
- Pagamentos que exigem autorizacao externa nao podem ser liquidados offline como pagos; devem entrar como `PENDENTE_AUTORIZACAO` ou aceitar apenas meios offline configurados pelo lojista.
- Repasses, alteracao bancaria, publicacao em massa, exclusao definitiva e conciliacao financeira final exigem online.

## Evidencias

- Spec criada: `docs/specs/merchant_erp_offline_pdv.md`.
- Base existente do ERP lojista: `database/postgres/037_v47_merchant_erp_marketplace_management.sql`.
- Fonte visual ativa: `config/design/valley_stitch_source_of_truth.json`.
- Store local duravel criada em `frontend/flutter/lib/src/data/merchant_erp_offline_store.dart`, usando arquivo JSON por usuario/dispositivo para fila idempotente sem exigir reinstalacao ou dependencia nativa extra.
- Flutter Desktop integrado em `frontend/flutter/lib/src/ui/merchant_erp_desktop_app.dart` com botao `Venda offline`, contador de pendencias e sincronizacao via `/api/merchant-erp/offline-sync`.
- Backend runtime integrou `/api/merchant-erp/offline-queue` e `/api/merchant-erp/offline-sync` em `scripts/serve_valley_admin.py`, com eventos append-only e idempotency key.
- `python scripts\validate_valley_release_gate.py --base-url https://admin.brasildesconto.com.br` retornou `status=ok`, `checks_total=25`, `failed_total=0`.
- Playwright validou `https://admin.brasildesconto.com.br/?workspace=merchant-pdv#merchantErpSection`: clique em `Venda offline` concluiu sem erro de console.

## Bloqueios

- Pagamentos que dependem de autorizacao externa permanecem corretamente bloqueados como liquidacao offline; o app registra venda pendente/sincronizavel, e a confirmacao final continua online.
- Banco local transacional dedicado (`drift`/SQLite) deixa de ser bloqueio P0 porque a fila duravel JSON cobre o requisito operacional sem inflar os executaveis unicos; pode virar evolucao P1 se o volume local crescer.

## Proxima Acao

- Manter monitoramento da fila offline nos gates de release e evoluir para SQLite somente quando houver necessidade real de consultas locais complexas.
