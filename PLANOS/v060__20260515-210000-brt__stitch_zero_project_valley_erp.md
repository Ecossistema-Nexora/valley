<!--
PROPOSITO: Registrar a solicitacao obrigatoria de projeto novo no Stitch para Valley ERP.
CONTEXTO: O usuario determinou que a especificacao Markdown atualizada e a logomarca Valley sejam direcionadas ao servidor MCP Stitch para criar um projeto do zero.
REGRAS: Gerenciar este fluxo pelo Codex via PLANOS/INDEX.md, manter segredos fora do git e preservar o caminho Stitch -> Figma -> Flutter.
-->

# v060 - Stitch zero project Valley ERP

## Escopo

Direcionar a especificacao mestre `Especificacao_Master_Valley_ERP_v1.md`, agora persistida no repositorio, junto com a logomarca oficial Valley, para o MCP Stitch criar um projeto novo do Valley ERP seguindo as diretrizes de Admin, Lojista, Usuario APK Android, Entregador, PostgreSQL e MongoDB.

## Checklist

- [x] Persistir a especificacao mestre atualizada dentro do repositorio em `docs/specs/valley_erp_zero_project_database_ui_directives.md`.
- [x] Localizar a logomarca oficial Valley em `assets/brand/logo-valley-official.png`.
- [x] Sanear a configuracao versionada do Stitch para usar `STITCH_API_KEY` local, sem gravar chave em git.
- [x] Criar pacote de handoff para o Stitch em `docs/specs/stitch_zero_project_request_valley_erp.md`.
- [x] Registrar o fluxo como plano obrigatorio v060 em `PLANOS/INDEX.md`.
- [x] Criar projeto novo privado no Stitch via MCP.
- [x] Registrar no plano o identificador/link do projeto Stitch criado.
- [x] Enviar DESIGN.md, criar design system e gerar telas prioritarias no projeto Stitch.
- [ ] Encaminhar o resultado Stitch para Figma e depois para Flutter, mantendo a cadeia Stitch -> Figma -> Flutter.

## Diretrizes Obrigatorias Para O Stitch

- Criar um projeto novo chamado **Valley ERP - Omniverse Operacional**.
- Usar `docs/specs/valley_erp_zero_project_database_ui_directives.md` como especificacao principal.
- Usar `assets/brand/logo-valley-official.png` como logomarca padrao.
- Gerar superficies por grupo: Admin, Lojista, Usuario APK Android e Entregador.
- Incluir login Valley ERP Lojista com botao `Cadastre-se`.
- Incluir onboarding empresarial com Dados da Empresa, Representante Legal, Configuracao de Admin e Perfis/Convites.
- As telas do entregador devem usar tema verde.
- Refletir a arquitetura PostgreSQL/MongoDB documentada, sem expor segredos, custos brutos, formulas de markup ou margem ao usuario final.
- Nenhum botao morto e nenhum placeholder de demo deve ser tratado como entrega final.

## Artefatos

- `docs/specs/valley_erp_zero_project_database_ui_directives.md`
- `docs/specs/stitch_zero_project_request_valley_erp.md`
- `docs/specs/valley_stitch_design_system_v060.md`
- `docs/specs/stitch_v060_generated_screens_summary.md`
- `assets/brand/logo-valley-official.png`
- `docs/specs/merchant_erp_modules_operations_stitch_handoff.md`
- `docs/specs/merchant_erp_stitch_module_layout_contract.json`

## Projeto Stitch

- Nome: `Valley ERP - Omniverse Operacional`
- ID: `12516070127536900621`
- Resource name: `projects/12516070127536900621`
- Visibilidade: `PRIVATE`
- Design system: `assets/c566fbedbd564135b573140ef520a79f`
- DESIGN.md screen: `projects/12516070127536900621/screens/3647313235686944126`
- Telas geradas: `15` entradas registradas em `docs/specs/stitch_v060_generated_screens_summary.md`.

## Bloqueios

- A ferramenta Stitch nao apareceu como tool nativa do Codex, mas o endpoint MCP HTTP respondeu e criou o projeto.
- O segredo recebido deve permanecer local como `STITCH_API_KEY`; nao deve ser versionado em `.mcp.json`, `.vscode/mcp.json`, planos ou docs.

## Proxima Acao

Encaminhar `docs/specs/stitch_v060_generated_screens_summary.md` para Figma como camada de inspecao/handoff e depois traduzir as telas aprovadas para Flutter.
