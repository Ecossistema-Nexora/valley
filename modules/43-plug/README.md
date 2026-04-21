# 43. Valley Plug

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `PLUG`
- Subtitulo: `Maquininha & Tap-to-Pay`
- Dominio: `commerce_fintech_assets`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)
- Cobertura mapeada: PostgreSQL: 3 entidades mapeadas.

## Finalidade

Maquininha, Tap-to-Pay, MDR e antecipacao D+0.

## Atores Primarios

- lojista
- operador de adquirencia
- comprador presencial

## Capacidades-Chave

- tap-to-pay
- maquininha
- antecipacao de recebivel

## Dependencias

PAY

## Integracoes

WALLETS, BUSINESS

## Mapa De Dados

### PostgreSQL

- `transactions`
- `wallets`
- `merchant_storefronts`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `plug.device.activated`
- `plug.payment.authorized`
- `plug.advance.requested`

## Compliance E Operacao

- pci_boundary
- mdr_audit
- settlement_traceability

## Superficies Admin

- painel de adquirencia
- monitor de terminais
- fila de antecipacao

## Proxima Onda

- criar contrato especifico de terminal
- definir MDR por faixa
- ligar fluxo D0 de antecipacao

## Trilha De Implantacao

1. Confirmar contrato de dados com `users.user_id` como no central.
2. Definir tabelas PostgreSQL quando houver dinheiro, identidade, contrato, documento ou transacao.
3. Definir colecoes MongoDB quando houver IA, social, telemetria, eventos volumosos ou conteudo semi-estruturado.
4. Registrar regras de negocio em `business_rule_definitions` quando houver pricing, comissao, risco, permissao ou compliance.
5. Atualizar este README, o Manual Online e a vertente PDF a cada mudanca.

## Criterios De Pronto

- Schema validado ou justificativa de descarte registrada.
- Integracoes com `PAY`, `ID`, `DOCS`, `ORDERS` ou `TRANSACTIONS` documentadas quando existirem.
- Teste ou validacao tecnica registrada.
- Comentarios em portugues simples com termos tecnicos em ingles onde fizer sentido.
- Blueprint operacional alinhado ao registry detalhado.
