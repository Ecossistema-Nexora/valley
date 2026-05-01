# Manual do Ambiente Valley

## Objetivo
Este manual descreve de forma simples como configurar o ambiente do projeto Valley, com foco em padronização, redução de custo operacional e menor risco de falhas humanas.

## Arquivo principal de segredos
- Caminho: `tmp/runtime/codex-cloud-secrets.env`
- Finalidade: servir como template de variáveis sensíveis para execução local, CI e automações.
- Integração: scripts de runtime e serviços web do projeto podem consumir essas variáveis via `source` no shell ou injeção por pipeline.

## Como usar
1. Copie o template para um arquivo seguro do seu ambiente.
2. Substitua todos os valores com placeholder (`<...>`) por credenciais reais.
3. Nunca publique segredos reais no repositório.
4. Valide a configuração com testes de conexão (banco, SMTP e APIs).

## Justificativas técnicas
- **Padronização:** reduz divergência entre ambientes e acelera onboarding.
- **Segurança:** evita vazamento por uso de placeholders no versionamento.
- **Custo:** diminui retrabalho com incidentes de configuração.

## Referências de integração
- Template de segredos: `tmp/runtime/codex-cloud-secrets.env`
- Scripts que podem depender de runtime/env: pasta `scripts/`

