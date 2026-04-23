# Valley Vision - Module Catalog Drift Notes

Fontes lidas:

- `database/postgres/004_v47_control_plane_modules_rules.sql`
- `database/postgres/007_v47_module_delivery_automation.sql`
- `database/postgres/015_v47_module_blueprints_registry.sql`
- `config/modules_v47.json`
- `config/modules_v47_blueprints.json`
- `modules/INDEX.md`

## Modulos 42-47 faltando em `module_catalog`

Os modulos ausentes no seed de `module_catalog` sao:

1. `BUSINESS`
2. `PLUG`
3. `UP`
4. `MEDIA`
5. `CHAT`
6. `DOCS`

Evidencia:

- `database/postgres/004_v47_control_plane_modules_rules.sql` popula `module_catalog` ate o modulo 41.
- `config/modules_v47.json` e `modules/INDEX.md` trazem 42-47 com os codigos acima.

## Local de menor impacto para corrigir

O local conceitual de dono e `database/postgres/004_v47_control_plane_modules_rules.sql`, porque e ali que o `module_catalog` nasce.

Operacionalmente, porem, o menor impacto e criar uma nova migration aditiva imediatamente apos o `004`, em vez de editar o `004` ja existente.

Motivo:

- evita alterar o historico de uma migration base;
- preserva idempotencia para ambientes que ja aplicaram `004`;
- reduz risco em repositorios onde migrations antigas ja foram executadas em mais de um ambiente.

## Tipo de correcao recomendado

Recomendacao: nova migration com `INSERT ... ON CONFLICT (module_code) DO UPDATE`.

Nao recomendo atualizar a migration antiga como unica abordagem, mesmo que o SQL seja idempotente, porque isso mistura correcao de estado com historico de bootstrap.

Estrutura esperada da correcao:

- `INSERT` das 6 linhas faltantes em `module_catalog`;
- `ON CONFLICT (module_code) DO UPDATE SET ...`;
- manter `module_number` coerente com 42-47;
- manter `module_code`, `module_name`, `primary_audience`, `secondary_audience`, `central_function`, `monetization_model`.

## Risco de duplicidade com `module_delivery_registry`

Baixo, desde que a correcao fique restrita a `module_catalog`.

Pontos observados:

- `database/postgres/007_v47_module_delivery_automation.sql` ja contem `module_delivery_registry` com os mesmos modulos 42-47.
- `module_delivery_registry.module_code` e `UNIQUE`.
- `database/postgres/015_v47_module_blueprints_registry.sql` nao insere novas linhas; ele apenas adiciona `module_blueprint_json` e faz `UPDATE ... FROM blueprint_source` por `module_code`.

Conclusao:

- nao ha duplicidade a criar em `module_delivery_registry` se a correcao for apenas no `module_catalog`;
- o risco real e drift de estado entre `module_catalog` e `module_delivery_registry` caso alguma automacao futura tente reimportar ambos sem `ON CONFLICT`.

