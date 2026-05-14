PROPOSITO: Tornar cadastro e checkout obrigatoriamente completos para identidade, CPF, endereco principal, CEP e destinatario.
CONTEXTO: O usuario exigiu nome completo, CPF, data de nascimento, telefone, email, busca automatica de endereco por CEP, confirmacao de logradouro, numero, complemento, tipo de endereco e checkout com endereco principal ou alternativo.
REGRAS: Nao aceitar cadastro sem CPF estruturalmente valido; nao aceitar checkout sem endereco completo e destinatario; preservar frete consultado no fornecedor e dados white-label.

# v049 - Cadastro e Checkout com CPF, CEP e Destinatario

## Checklist

- [x] Criar validacao backend de CPF com data de nascimento e referencia oficial da Receita.
- [x] Criar endpoint backend de busca de endereco por CEP.
- [x] Exigir data de nascimento, telefone e endereco principal completo no cadastro.
- [x] Incluir tipo do endereco e confirmacao de logradouro no cadastro.
- [x] Atualizar Flutter para validar CPF/data e buscar CEP automaticamente no cadastro.
- [x] Atualizar checkout para destinatario separado, endereco principal ou alternativo e busca por CEP.
- [ ] Validar endpoints localmente.
- [ ] Validar `flutter analyze` dos arquivos alterados.
- [ ] Reiniciar servidor admin e validar endpoints no dominio publico.
- [ ] Acionar Valley Module Automation Engine.

## Criterios De Aceite

- Cadastro exige nome completo, CPF, data de nascimento, telefone, email e endereco principal.
- CEP preenche logradouro, bairro, cidade e UF para confirmacao do usuario.
- Usuario informa numero, complemento e tipo do endereco.
- Checkout permite usar endereco principal ou informar outro endereco de entrega.
- Checkout permite destinatario diferente do titular da conta.

