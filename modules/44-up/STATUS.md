# Status - Valley Up

- [x] Registry canonico criado.
- [x] Suporte base de schema ja implantado ou parcialmente implantado.
- [x] Contrato operacional inicial gerado.
- [x] Schema PostgreSQL especifico revisado.
- [x] Schema MongoDB especifico revisado.
- [x] Regras de negocio cadastradas ou descartadas.
- [x] Fluxos Admin/RBAC/ABAC definidos.
- [x] Testes de integracao planejados.
- [x] Manual Online atualizado.
- [x] PDF regenerado.

Evidencias da revisao:

- PostgreSQL: `database/postgres/005_v47_domain_tables_core_first.sql` cobre `affiliate_referrals`, com integridade para `order_id` ou `purchase_transaction_id`, valor de comissao em BRL e triggers append-only que impedem `UPDATE` e `DELETE`.
- Runtime de incentivo complementar: `database/postgres/004_v47_control_plane_modules_rules.sql` entrega `gamification_campaigns` e a regra `BR-UP-COMMISSION-001`, enquanto `database/postgres/010_v47_rule_growth_marketplace_runtime.sql` entrega `pepita_accounts`, `pepita_ledger`, `gold_campaigns` e `gold_campaign_events`, formando a retaguarda de atribuicao e incentivo conectada ao funil de afiliacao.
- MongoDB: `database/mongodb/001_ai_social_telemetry.mongo.js` cobre `social_videos` e `influencer_metrics`, que fecham o lado de acquisicao, `commission_link` e performance de creator/campanha ligado ao modulo.
- Regras de negocio: `BR-UP-COMMISSION-001` ja registra a comissao de afiliados no plano de controle. A decisao revisada e considerar isso suficiente por agora, sem abrir rule runtime duplicado para settle basico.
- Admin/RBAC/ABAC: o modulo herda `module_catalog`, `admin_permissions` e `admin_action_audit`, suficiente para growth ops, creator ops e suporte.
- Manual/PDF: `MANUAL_ONLINE/README.md` agora registra `UP` como modulo revisado sobre `affiliate_referrals`, `social_videos`, `influencer_metrics` e regra canonica de comissao. O PDF oficial foi regenerado apos esta atualizacao documental.

Plano minimo de testes de integracao:

1. Criar `affiliate_referral` com `referrer_id`, `order_id` ou `purchase_transaction_id`, `commission_amount_brl` e `payout_at` nulo, validando a trilha append-only de comissao.
2. Tentar `UPDATE` ou `DELETE` em `affiliate_referrals`, confirmando que a protecao append-only esta ativa.
3. Inserir `social_video` com `creator_user_id`, `commission_link`, `product_refs`, `status = 'ACTIVE'` e `visibility`, validando a superficie publica de atribuicao.
4. Inserir `influencer_metrics` para a mesma campanha com `campaign_id`, `views`, `clicks`, `conversions`, `gross_sales_brl` e `commission_brl`, confirmando analytics do funil.
5. Ler a cadeia `social_videos` -> `influencer_metrics` -> `affiliate_referrals`, validando a ponte entre conteudo, performance e settle financeiro do modulo.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
