# ERP Lojista Valley - Privilegios e Usuarios

## Objetivo

Criar uma base de privilegios para usuarios do Valley ERP Lojista, com associacao a uma loja, gestao pelo administrador lojista e trilha auditavel de qualquer mudanca de acesso.

## Principio

O administrador lojista gerencia a propria equipe dentro do escopo da loja. Nenhum operador deve receber privilegios globais do Valley. Toda permissao efetiva precisa derivar de:

- papel do usuario na loja;
- perfil de papel aplicado;
- concessao direta feita por administrador lojista;
- restricoes de horario, dispositivo, offline e limite operacional.

## Papeis Base

- `OWNER`: dono da loja, acesso total e autoridade final.
- `ADMIN`: administrador lojista, gerencia equipe, configuracoes e operacao.
- `MANAGER`: gerente, aprova rotinas de PDV, estoque e pedidos dentro de limites.
- `CASHIER`: operador de caixa, usa PDV e rotinas de venda.
- `WAREHOUSE`: operador de estoque, inventario, separacao e movimentacao.
- `ACCOUNTANT`: financeiro/contabil, leitura financeira e relatorios.
- `SUPPORT`: atendimento, pedidos, clientes e suporte.
- `VIEWER`: leitura operacional.

## Privilegios Base

- `erp.menu.open`: abrir menu principal.
- `pdv.session.open`: abrir caixa.
- `pdv.sale.create`: registrar venda.
- `pdv.sale.cancel`: cancelar venda.
- `pdv.cash.move`: sangria, suprimento e ajuste.
- `pdv.session.close`: fechar caixa.
- `products.read`: consultar produtos.
- `products.write`: editar produtos.
- `inventory.read`: consultar estoque.
- `inventory.adjust`: ajustar estoque.
- `orders.read`: consultar pedidos.
- `orders.fulfill`: separar pedidos.
- `finance.read`: consultar financeiro.
- `finance.approve`: aprovar fechamento, repasse e conciliacao.
- `integrations.manage`: gerenciar conectores e webhooks.
- `reports.export`: exportar relatorios.
- `team.manage`: gerenciar equipe.
- `security.manage`: gerenciar MFA, sessoes e risco.
- `settings.manage`: gerenciar configuracoes.

## Regras De Administracao

- Apenas `OWNER`, `ADMIN` e `MANAGER` ativos podem conceder privilegios.
- `MANAGER` deve ter limites menores e nao deve administrar seguranca sensivel.
- `team.manage`, `security.manage`, `finance.approve` e `integrations.manage` exigem rede online.
- Privilegios offline precisam estar marcados como `offline_allowed`.
- Toda alteracao de papel ou privilegio deve gerar evento append-only em `merchant_erp_privilege_audit_events`.
- Concessao direta de usuario prevalece sobre perfil de papel, desde que ativa e dentro da validade.

## Contrato De Dados

Migration: `database/postgres/038_v47_merchant_erp_privileges_rbac.sql`.

Tabelas:

- `merchant_erp_privileges`: catalogo canonico de privilegios.
- `merchant_erp_role_profiles`: perfis de papel globais e customizados por lojista.
- `merchant_erp_role_profile_privileges`: privilegios por perfil.
- `merchant_erp_staff_privilege_grants`: concessoes diretas por usuario da equipe.
- `merchant_erp_privilege_audit_events`: auditoria append-only.

View:

- `v_merchant_erp_staff_effective_privileges`: privilegios efetivos por usuario.

## UX Esperada

No modulo Equipe/Seguranca do ERP Lojista:

- listar usuarios associados a loja;
- mostrar papel, status, ultimo acesso e privilegios efetivos;
- permitir trocar papel por perfil;
- permitir conceder/negar privilegios pontuais;
- destacar privilegios sensiveis e offline;
- exigir confirmacao para privilegios financeiros, seguranca e integracoes;
- mostrar historico de alteracoes por administrador.

## Criterios De Aceite

- Todo usuario de equipe fica vinculado a `merchant_user_id`.
- Administrador lojista consegue associar usuario e papel.
- Privilegios de PDV offline aparecem separadamente.
- Operador de caixa nao consegue aprovar repasse financeiro.
- Operador de estoque nao consegue alterar configuracao bancaria.
- Auditoria de privilegios e imutavel.
- A view efetiva retorna o que o frontend precisa para habilitar ou bloquear botoes.
