# Valley GitHub Binding

Este workspace opera somente contra o repositorio:

- `https://github.com/Ecossistema-Nexora/valley`

## Politica

- O remote Git canonico e `origin`.
- O fetch e o push devem usar `https://github.com/Ecossistema-Nexora/valley.git`.
- O conector GitHub do agente continua `platform-managed`, mas seu escopo de repositorio fica limitado a este repo.
- Qualquer referencia a outro repositorio deve ser tratada apenas como material historico ou documental, nunca como target de automacao deste workspace.

## Arquivo canonico

- `config/github/VALLEY_GITHUB_REPOSITORY.json`

## Bootstrap

- `scripts/bootstrap_valley_tooling.ps1` agora verifica e corrige o binding do remote `origin` para este repositorio.
