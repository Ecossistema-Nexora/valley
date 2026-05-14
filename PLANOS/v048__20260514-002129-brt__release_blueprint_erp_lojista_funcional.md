PROPOSITO: Substituir o ERP Lojista demonstrativo por um release blueprint funcional, autenticado e persistente.
CONTEXTO: O pacote v047 abriu uma experiencia desktop instalavel, mas ainda continha sessao local e registros estaticos; o usuario exigiu todas as funcionalidades ativas de forma persistente.
REGRAS: Remover modo demo/local, exigir login online de lojista, carregar modulos a partir de endpoint autenticado, gravar acoes em runtime append-only e republicar os artefatos.

# v048 - Release Blueprint ERP Lojista Funcional

## Checklist

- [x] Identificar a causa da aparencia demo no app desktop v047.
- [x] Criar endpoint autenticado `/api/merchant-erp/blueprint` no servidor Valley.
- [x] Criar endpoint persistente `/api/merchant-erp/action` para botoes Salvar/Sincronizar.
- [x] Remover sessao local e botao de sessao local do app desktop.
- [x] Fazer o app consumir somente o blueprint online apos login de lojista.
- [x] Validar login, blueprint e acao persistente por API local.
- [x] Validar `flutter analyze` do app desktop.
- [x] Gerar pacote Windows/Linux v048 atualizado.
- [x] Publicar manifesto e links v048.
- [x] Atualizar PDF/release docs se o pacote for fechado nesta rodada.

## Criterios De Aceite

- O ERP nao abre modulo operacional sem servidor online e sessao de lojista valida.
- O menu principal e as tabelas sao alimentados por `/api/merchant-erp/blueprint`.
- Os botoes `Salvar` e `Sincronizar` registram evento em `tmp/runtime/valley-merchant-erp-events.jsonl`.
- O pacote v048 substitui o v047 como release recomendado do ERP Lojista.

## Evidencias

- Login local e publico do lojista retornou `status=ok` e papel `MERCHANT`.
- Blueprint local e publico retornou 12 modulos ativos.
- Acoes locais e publicas gravaram eventos em `tmp/runtime/valley-merchant-erp-events.jsonl`.
- Manifesto publico v048 retornou HTTP 200.
- ZIP Windows publico v048 retornou HTTP 200.
- Release blueprint publico v048 retornou HTTP 200.
- ZIP Windows, pacote Linux, PDF e mensagem de links foram enviados pelo Telegram com `ok=true`.
