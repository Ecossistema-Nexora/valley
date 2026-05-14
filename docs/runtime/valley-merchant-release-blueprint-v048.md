PROPOSITO: Definir o release blueprint funcional do Valley ERP Lojista v048.
CONTEXTO: O release desktop anterior continha rotas locais demonstrativas; o v048 passa a exigir servidor online, sessao de lojista e acoes persistidas.
REGRAS: Nao usar modo demo, nao abrir tela operacional sem blueprint autenticado e nao deixar botoes sem gravacao no runtime.

# Valley ERP Lojista - Release Blueprint v048

## Fonte Online Obrigatoria

- Login: `POST https://admin.brasildesconto.com.br/api/auth/login` com `scope=merchant`.
- Blueprint: `GET https://admin.brasildesconto.com.br/api/merchant-erp/blueprint` com `Authorization: Bearer <token>`.
- Acoes: `POST https://admin.brasildesconto.com.br/api/merchant-erp/action` com `Authorization: Bearer <token>`.
- Persistencia: `tmp/runtime/valley-merchant-erp-events.jsonl`.

## Funcionalidades Ativas

| Modulo | Origem do dado | Acao persistente |
| --- | --- | --- |
| Vendas | Checkout, eventos ERP e runtime de pagamentos | `save`, `sync` |
| Produtos | Catalogo importado e precificacao por fornecedor | `save`, `sync` |
| Estoque | Catalogo STOCK runtime com custo, quantidade e margem | `save`, `sync` |
| Pedidos | Checkout e fila de pedido fornecedor | `save`, `sync` |
| Clientes | Runtime de autenticacao e usuarios | `save`, `sync` |
| Financeiro | Inventario, margem e checkout | `save`, `sync` |
| Checkout | Status Mercado Pago e tentativas de checkout | `save`, `sync` |
| Entregas | Frete, cotacao e pedido fornecedor | `save`, `sync` |
| Marketplace | Integracoes, fornecedores e publicacao | `save`, `sync` |
| Relatorios | Sumario de catalogo e eventos operacionais | `save`, `sync` |
| Configuracoes | Usuario lojista, permissoes e RBAC | `save`, `sync` |
| Suporte Helena | Bridge operacional e chamados persistidos | `save`, `sync` |

## Decisoes Do v048

- A sessao local foi removida do app desktop.
- O botao `Abrir sessao local` foi removido.
- O app nao usa mais registros estaticos compartilhados entre todos os modulos.
- O servidor gera o blueprint com dados reais do runtime disponivel.
- Cada clique operacional grava evento append-only no runtime para auditoria.

## Criterios De Publicacao

- `python -m py_compile scripts/serve_valley_admin.py` sem erro.
- Login local do usuario lojista de teste retorna `status=ok`.
- `GET /api/merchant-erp/blueprint` retorna 12 modulos ativos.
- `POST /api/merchant-erp/action` grava evento em `tmp/runtime/valley-merchant-erp-events.jsonl`.
- `flutter analyze` do entrypoint desktop sem issues bloqueantes.
- Pacote Windows v048 e manifesto publicados em `admin/downloads/v048`.

