# 17. Valley News & Podcast

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `NEWS_PODCAST`
- Subtitulo: `ContinuaMente`
- Dominio: `media_social_growth`
- Tier: `expansion`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: MongoDB: 1 colecoes mapeadas.

## Finalidade

Noticias, podcasts e conteudo editorial.

## Atores Primarios

- editor
- criador de audio
- consumidor

## Capacidades-Chave

- conteudo editorial
- episodios e blocos
- distribuicao midia

## Dependencias

MEDIA

## Integracoes

CREATOR, ADS

## Mapa De Dados

### PostgreSQL

- Nao aplicavel.

### MongoDB

- `news_content_items`

## Eventos Canonicos

- `news.story.published`
- `podcast.episode.released`
- `media.content.moderated`

## Compliance E Operacao

- editorial_governance
- copyright_traceability
- content_moderation

## Superficies Admin

- cms editorial
- fila de revisao
- monitor de distribuicao

## Proxima Onda

- fechar taxonomia editorial
- ligar agenda de publicacao
- amarrar politica de moderacao

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
