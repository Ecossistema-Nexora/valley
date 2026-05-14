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
- [ ] Adicionar dependencias locais do Flutter Desktop para banco local, conectividade e fila de sync.
- [ ] Implementar camada local `merchant_erp_offline_store` com schema de caixa, vendas, itens, estoque espelho e fila.
- [ ] Implementar servico de sincronizacao imediata apos reconexao com idempotency key por evento.
- [ ] Adaptar telas PDV/Estoque/Pedidos para indicar online, offline, pendente e sincronizado.
- [ ] Validar com teste: vender offline, reconectar, sincronizar e conferir ausencia de duplicidade.

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
- Dependencias Flutter atuais ainda nao incluem banco local transacional dedicado.

## Bloqueios

- A implementacao real precisa escolher a biblioteca local: recomendacao inicial e `drift` + `sqlite3_flutter_libs` para desktop, com fallback de `shared_preferences` apenas para preferencias simples.
- Validacao de pagamento offline depende da politica comercial do meio de pagamento: dinheiro e venda pendente sao seguros; cartao/PIX dependem de autorizacao externa.

## Proxima Acao

- Implementar a camada local offline no Flutter Desktop e o contrato de sync no backend/admin runtime.
