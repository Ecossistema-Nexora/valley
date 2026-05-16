<!--
PROPOSITO: Solicitar ao Stitch MCP a criacao de um projeto novo do Valley ERP a partir da especificacao mestre e da marca oficial.
CONTEXTO: Este handoff consolida o arquivo de diretrizes de banco/UI, a logomarca Valley e as regras obrigatorias para gerar o projeto do zero no Stitch.
REGRAS: Nao versionar chaves Stitch, preservar nomenclatura Valley/Helena/V-Coin e manter o fluxo Stitch -> Figma -> Flutter.
-->

# Stitch Zero Project Request - Valley ERP

## Objetivo

Criar um projeto novo no Stitch, do zero, para o ecossistema Valley ERP, usando a especificacao mestre de banco/UI, a logomarca oficial Valley e os contratos operacionais ja versionados no repositorio.

## Anexos Obrigatorios Para O Stitch

- Especificacao mestre atualizada:
  `docs/specs/valley_erp_zero_project_database_ui_directives.md`
- Logomarca oficial Valley:
  `assets/brand/logo-valley-official.png`
- Design system para upload no Stitch:
  `docs/specs/valley_stitch_design_system_v060.md`
- Tokens estruturados por persona:
  `config/design/valley_persona_design_system.json`
- Handoff operacional de modulos:
  `docs/specs/merchant_erp_modules_operations_stitch_handoff.md`
- Especificacao operacional por persona:
  `docs/specs/valley-operational-spec-admin-erp-user-rider.md`
- Especificacao tecnica fechada por tela:
  `docs/specs/valley-screen-technical-spec-admin-erp-user-rider.md`
- Contrato estruturado:
  `docs/specs/merchant_erp_stitch_module_layout_contract.json`

## Prompt Para Envio Ao Stitch

Crie um projeto novo chamado **Valley ERP - Omniverse Operacional**.

Use a logomarca oficial Valley anexada como base de identidade visual e gere as superficies do zero, sem reaproveitar landing page generica. A primeira tela deve ser uma experiencia operacional real, com densidade de ERP, navegacao por perfil e modulos funcionais.

Siga integralmente a especificacao mestre anexada, com foco em:

- Admin: gestao total de modulos, regras, servicos, cadastros, funcoes, APIs, tokens, usuarios, auditoria e Modo Deus.
- Lojista: Valley ERP com onboarding empresarial, controle individual de modulos, regras, servicos, equipe, estoque, vendas, financeiro, agenda, integracoes e operacao por filial.
- Usuario APK Android: modulos MVP, perfil limitado, finanças visiveis, compras, favoritos, Stock, Marketplace, agendamentos, checkout e chats de suporte.
- Entregador: cadastro, veiculo, associacao de veiculo, coletas, entregas, ocorrencias, classificacao privada de cliente, comissoes, historico e bloqueio de enderecos.
- Banco de dados: respeitar os grupos PostgreSQL e MongoDB definidos no documento mestre, usando UUID, `tenant_id`, `branch_id`, auditoria, ledgers append-only e segregacao de visibilidade.
- Especificacao operacional: respeitar fluxos, componentes, estados, permissao, auditoria, notificacoes e responsabilidades por persona definidos em `valley-operational-spec-admin-erp-user-rider.md`.
- Especificacao por tela: para cada tela gerada, obedecer wireframe textual, campos, validacoes frontend/backend, APIs, eventos, tabelas impactadas, estados e compliance de `valley-screen-technical-spec-admin-erp-user-rider.md`.

## Telas Prioritarias

1. Admin Valley - Painel Modo Deus
2. Valley ERP - Login Lojista com botao Cadastre-se
3. Valley ERP - Cadastro de Empresa e Usuarios
4. Valley ERP - Dashboard Operacional Lojista
5. Valley ERP - Produtos, Estoque, Pedidos e Etiquetas
6. Valley ERP - Financeiro, Agenda e Integracoes
7. APK Usuario - Home MVP modular
8. APK Usuario - Stock, Marketplace, Checkout e Minhas Compras
9. APK Usuario - Chat Stock/Marketplace/Suporte Helena
10. Entregador - Home Logistica em tema verde
11. Entregador - Coletas, Entregas, Ocorrencias e Comissoes

## Regras Visuais

- PT-BR em todas as telas.
- Aplicar as quatro bases visuais mandatarias:
  - Admin em preto com acentos neon para governanca.
  - Lojista / ERP em ciano produtivo para operacao empresarial.
  - Usuario em fundo claro para consumo, compras e Helena.
  - Entregador em chumbo com alto contraste para leitura em transito.
- Usar os componentes compartilhados `TopAppBar`, `BottomNavBar` e `NavigationDrawer` como primitivas de navegacao.
- Interface densa, sobria e operacional para ERP; nada de hero marketing no produto interno.
- Telas do entregador com tema verde, contraste alto e comandos principais sempre visiveis.
- Helena deve aparecer como assistente contextual, sem pop-ups invasivos.
- Nao exibir custo bruto, formulas de markup ou margem ao usuario final.
- Nao criar botoes mortos; cada acao deve ter estado real: vazio, carregando, erro, sucesso e historico.
- Cards apenas para itens repetidos, modais ou ferramentas realmente enquadradas.
- Preservar a marca Valley, Helena e V-Coin. Nao introduzir nomes antigos.

## Criterios De Aceite Do Projeto Stitch

- Projeto novo criado no Stitch com as superficies acima.
- Logo Valley aplicado corretamente.
- Estrutura por perfil: Admin, Lojista, Usuario e Entregador.
- Login Lojista possui acesso `Cadastre-se`.
- Onboarding empresarial possui as quatro secoes: Dados da Empresa, Representante Legal, Configuracao de Admin, Perfis e Convites.
- Entregador possui tema verde e fluxos de ocorrencia obrigatoria.
- UI reflete os grupos de dados do PostgreSQL/MongoDB definidos na especificacao.
- Exportacao posterior deve seguir para Figma e depois Flutter, conforme regra obrigatoria do Valley.

## Status Operacional Codex

- O arquivo de especificacao mestre foi persistido no repositorio.
- A logomarca oficial foi localizada em `assets/brand/logo-valley-official.png`.
- O design system de envio ao Stitch foi persistido em `docs/specs/valley_stitch_design_system_v060.md`.
- O projeto privado foi criado no Stitch como `projects/12516070127536900621`.
- O design system Stitch foi criado como `assets/c566fbedbd564135b573140ef520a79f`.
- As telas geradas foram registradas em `docs/specs/stitch_v060_generated_screens_summary.md`.
- As especificacoes operacional e tecnica por tela foram importadas para `docs/specs/` como anexos obrigatorios de continuidade.
- A logomarca enviada pelo usuario foi validada contra `assets/brand/logo-valley-official.png` com SHA256 identico `53E4158D234EF25AE845083C4F0A1356E1BF37BA3E10DCB84BDB9BACCB18EADA`.
- A publicacao ativa foi aplicada como `20260516_valley_erp_v060`.
- Galeria ativa: `/stitch/20260516_valley_erp_v060/`.
- Manifesto ativo: `/stitch/20260516_valley_erp_v060/manifest.json`.
- Inventario ativo: `docs/design/stitch_valley_erp_v060_inventory.json`.
- Fonte de verdade ativa: `config/design/valley_stitch_source_of_truth.json`.
- Artefatos antigos `20260513_valley_erp_v2` foram removidos da galeria/export ativos e mantidos apenas como referencia obsoleta em metadados.
- A chave Stitch deve permanecer somente como `STITCH_API_KEY` local; nenhum segredo deve entrar em git.
- O handoff Figma fica versionado nos documentos acima e o Flutter ja consome `20260516_valley_erp_v060`.
