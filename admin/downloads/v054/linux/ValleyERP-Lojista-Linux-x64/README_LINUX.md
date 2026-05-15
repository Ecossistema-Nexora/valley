PROPOSITO: Instalar o Valley ERP Lojista no Linux.
CONTEXTO: Pacote desktop v054 com script de instalacao e caminho de build a partir do repo.
REGRAS: O binario Linux deve ser compilado em host Linux com Flutter Desktop habilitado quando nao estiver precompilado no pacote.

# Valley ERP Lojista - Linux x64

## Instalar com binario precompilado

``bash
bash install-valley-erp-lojista-linux.sh
``

## Compilar e instalar a partir do repositÃ³rio

``bash
SOURCE_ROOT=/caminho/para/VALLEY bash install-valley-erp-lojista-linux.sh
``

## Gerar bundle Linux manualmente

``bash
bash build-linux-from-source.sh /caminho/para/VALLEY
``

API base usada por padrao: $ApiBaseUrl