# Escopo Atual De Categorias Para Importacao Dropshipping

Gerado a partir de `tmp/runtime/valley-dropshipping-source-categories.json`.

## Status Dos Conectores

- `cjdropshipping`: conector real ligado. A API de categorias nao respondeu nos endpoints tentados; a rotina usou categorias reais ja existentes no runtime de importacao anterior.
- `aliexpress`: conector real ligado. Credenciais existem, mas o conector oficial de categorias/produtos ainda esta pendente neste runtime; a rotina usa o escopo alvo configurado ate habilitar o endpoint oficial.
- `alibaba`: conector real ligado. Sem token/API oficial persistido; a rotina usa o escopo alvo configurado e registra `dados_insuficientes`.

Scraping nao autorizado permanece bloqueado.

## CJ Dropshipping

| ID fornecedor | Categoria | Google Product Category | Origem |
|---|---|---|---|
| DAECCC3B-13D8-4978-86A8-61D3DF186134 | Audio | Electronics > Audio > Audio Components > Headphones & Headsets > Headphones | runtime_cache |
| 4D91D172-D6D0-429E-AABC-6F3325A273A6 | Casa | Home & Garden > Household Appliances > Vacuums | runtime_cache |
| 8FD4CA46-AA88-4CDC-8EBA-EBD8412152E2 | Creator Gear | Electronics > Audio > Audio Components > Microphones | runtime_cache |
| B200FABB-A76B-4750-9957-FEA3DCB21F1F | Premium Tech | Electronics > Electronics Accessories > Power > Power Adapters & Chargers | runtime_cache |
| 4D91D172-D6D0-429E-AABC-6F3325A273A6 | Smart Living | Hardware > Power & Electrical Supplies > Home Automation Kits | runtime_cache |
| 0AADEC4E-024A-41DF-8801-4A0204F0E568 | Smartphones | Electronics > Communications > Telephony > Mobile Phones | runtime_cache |
| C83EF2A0-8FA3-4713-9901-2FD6E4554D97 | Wearables | Apparel & Accessories > Jewelry > Watches | runtime_cache |

## AliExpress

| ID fornecedor | Categoria interna | Google Product Category | Origem |
|---|---|---|---|
| ae-001 | Casa > Cozinha > Organizadores | Home & Garden > Kitchen & Dining > Kitchen Storage & Organization | configured_target_scope |
| ae-002 | Casa > Limpeza > Utensilios | Home & Garden > Household Supplies > Household Cleaning Supplies | configured_target_scope |
| ae-003 | Pet Shop > Alimentacao | Animals & Pet Supplies > Pet Supplies | configured_target_scope |
| ae-004 | Pet Shop > Brinquedos e Acessorios | Animals & Pet Supplies > Pet Supplies > Pet Toys | configured_target_scope |
| ae-005 | Casa > Banheiro > Acessorios | Home & Garden > Bathroom Accessories | configured_target_scope |
| ae-006 | Comercio Local > Embalagens | Business & Industrial > Packaging Materials | configured_target_scope |
| ae-007 | Casa > Iluminacao LED | Home & Garden > Lighting | configured_target_scope |
| ae-008 | Celulares > Capas e Peliculas | Electronics > Communications > Telephony > Mobile Phone Accessories > Mobile Phone Cases | configured_target_scope |
| ae-009 | Celulares > Cabos e Carregadores | Electronics > Electronics Accessories > Power > Chargers | configured_target_scope |
| ae-010 | Auto > Acessorios Internos | Vehicles & Parts > Vehicle Parts & Accessories > Vehicle Interior Accessories | configured_target_scope |
| ae-011 | Audio > Fones Bluetooth | Electronics > Audio > Audio Components > Headphones & Headsets > Headphones | configured_target_scope |
| ae-012 | Auto > Organizadores e Suportes | Vehicles & Parts > Vehicle Parts & Accessories > Vehicle Interior Accessories | configured_target_scope |
| ae-013 | Bike > Acessorios | Sporting Goods > Outdoor Recreation > Cycling > Bicycle Accessories | configured_target_scope |
| ae-014 | Fitness > Acessorios de Treino | Sporting Goods > Exercise & Fitness > Fitness Accessories | configured_target_scope |
| ae-015 | Beleza > Organizadores e Ferramentas | Health & Beauty > Personal Care > Cosmetics | configured_target_scope |
| ae-016 | Ferramentas > Manuais | Hardware > Tools | configured_target_scope |
| ae-017 | Jardim > Irrigacao e Organizacao | Home & Garden > Lawn & Garden | configured_target_scope |
| ae-018 | Moda > Feminino > Blusas e Moletons | Apparel & Accessories > Clothing > Shirts & Tops | configured_target_scope |
| ae-019 | Moda > Acessorios | Apparel & Accessories | configured_target_scope |
| ae-020 | Infantil > Brinquedos Educativos | Toys & Games > Toys > Educational Toys | configured_target_scope |

## Alibaba

| ID fornecedor | Categoria interna | Google Product Category | Origem |
|---|---|---|---|
| ab-001 | Casa > Cozinha > Organizadores | Home & Garden > Kitchen & Dining > Kitchen Storage & Organization | configured_target_scope |
| ab-002 | Casa > Limpeza > Utensilios | Home & Garden > Household Supplies > Household Cleaning Supplies | configured_target_scope |
| ab-003 | Pet Shop > Alimentacao | Animals & Pet Supplies > Pet Supplies | configured_target_scope |
| ab-004 | Pet Shop > Brinquedos e Acessorios | Animals & Pet Supplies > Pet Supplies > Pet Toys | configured_target_scope |
| ab-005 | Casa > Banheiro > Acessorios | Home & Garden > Bathroom Accessories | configured_target_scope |
| ab-006 | Comercio Local > Embalagens | Business & Industrial > Packaging Materials | configured_target_scope |
| ab-007 | Casa > Iluminacao LED | Home & Garden > Lighting | configured_target_scope |
| ab-008 | Celulares > Capas e Peliculas | Electronics > Communications > Telephony > Mobile Phone Accessories > Mobile Phone Cases | configured_target_scope |
| ab-009 | Celulares > Cabos e Carregadores | Electronics > Electronics Accessories > Power > Chargers | configured_target_scope |
| ab-010 | Auto > Acessorios Internos | Vehicles & Parts > Vehicle Parts & Accessories > Vehicle Interior Accessories | configured_target_scope |
| ab-011 | Audio > Fones Bluetooth | Electronics > Audio > Audio Components > Headphones & Headsets > Headphones | configured_target_scope |
| ab-012 | Auto > Organizadores e Suportes | Vehicles & Parts > Vehicle Parts & Accessories > Vehicle Interior Accessories | configured_target_scope |
| ab-013 | Bike > Acessorios | Sporting Goods > Outdoor Recreation > Cycling > Bicycle Accessories | configured_target_scope |
| ab-014 | Fitness > Acessorios de Treino | Sporting Goods > Exercise & Fitness > Fitness Accessories | configured_target_scope |
| ab-015 | Beleza > Organizadores e Ferramentas | Health & Beauty > Personal Care > Cosmetics | configured_target_scope |
| ab-016 | Ferramentas > Manuais | Hardware > Tools | configured_target_scope |
| ab-017 | Jardim > Irrigacao e Organizacao | Home & Garden > Lawn & Garden | configured_target_scope |
| ab-018 | Moda > Feminino > Blusas e Moletons | Apparel & Accessories > Clothing > Shirts & Tops | configured_target_scope |
| ab-019 | Moda > Acessorios | Apparel & Accessories | configured_target_scope |
| ab-020 | Infantil > Brinquedos Educativos | Toys & Games > Toys > Educational Toys | configured_target_scope |
