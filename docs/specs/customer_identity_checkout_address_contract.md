PROPOSITO: Documentar o contrato de cadastro e entrega do comprador Valley.
CONTEXTO: Cadastro e checkout precisam operar com identidade minima, CPF, endereco principal confirmado por CEP e destinatario flexivel.
REGRAS: Nao armazenar senha em claro; CPF deve passar por validacao estrutural; endereco de checkout deve ser completo antes de cotar frete e pagar.

# Contrato - Cadastro, CPF, CEP e Entrega

## Cadastro De Usuario

Campos obrigatorios:

- Nome completo.
- CPF.
- Data de nascimento.
- Telefone principal.
- Email.
- Senha.
- CEP do endereco principal.
- Logradouro confirmado pelo usuario.
- Numero.
- Complemento numerico quando aplicavel.
- Tipo do endereco: casa, apartamento, comercial ou outro.
- Bairro, cidade e UF.

## Validacao De CPF

O backend valida os digitos verificadores do CPF e exige data de nascimento no formato `AAAA-MM-DD`.

O servico oficial da Receita Federal permanece referenciado no payload por `receita_public_url`. A consulta oficial completa depende da sessao publica da Receita e usa CPF e data de nascimento.

## Busca Por CEP

Endpoint:

```http
POST /api/actions/cep-lookup
```

Payload:

```json
{
  "postal_code": "01001000"
}
```

Resposta esperada:

```json
{
  "status": "ok",
  "payload": {
    "address": {
      "postal_code": "01001000",
      "street": "Praça da Sé",
      "neighborhood": "Sé",
      "city": "São Paulo",
      "state": "SP",
      "country": "BR"
    }
  }
}
```

## Checkout

O checkout deve aceitar duas rotas:

- Usar endereco principal do cadastro.
- Informar outro endereco de entrega.

Em ambos os casos, o usuario pode informar um destinatario diferente do titular da conta. O frete so pode ser cotado e repassado ao comprador depois de endereco completo com destinatario, CEP, logradouro, numero, tipo, bairro, cidade e UF.

