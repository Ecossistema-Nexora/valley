# Valley Frontend And Flutter Visual Identity

## Proposito

Esta especificacao contextualiza a logomarca oficial Valley no frontend atual e na futura base do Super APK em Flutter.

O objetivo visual e fazer o Valley parecer um super app premium, financeiro, operacional e inteligente, sem perder legibilidade para uso real.

## Ativo Oficial

- Logomarca canonica: `assets/brand/logo-valley-official.png`
- Espelho do cockpit web: `admin/assets/logo-valley-official.png`
- Tokens: `config/brand/valley_brand_tokens.v1.json`
- Tema Flutter base: `frontend/flutter/lib/valley_brand_theme.dart`

## Direcao De Marca

A marca Valley combina:

- fundo noturno profundo
- montanhas em violeta e azul
- brilho central como sinal de norte, confianca e orientacao
- assinatura branca forte

Traducao para UI:

- fundos principais podem usar `Night` e `Cosmic`
- acoes primarias usam `Violet`
- estados informativos e detalhes vivos usam `Cyan`
- texto principal em superficies claras usa `Ink`
- texto sobre fundo escuro usa `Snow`

## Paleta

| Token | Hex | Uso |
| --- | --- | --- |
| `night` | `#07051F` | fundo premium, splash, app shell |
| `cosmic` | `#151047` | gradiente secundario e app bars |
| `violet` | `#6F2CFF` | CTA principal, foco, progresso |
| `lilac` | `#BB8CFF` | destaque suave, grafico, halo |
| `cyan` | `#20C8F3` | informacao, status ativo, contraste tecnologico |
| `snow` | `#FFFFFF` | assinatura e texto sobre fundo escuro |
| `ink` | `#121827` | texto em superficies claras |

## Regras Para O Frontend Web

1. A logomarca deve aparecer na primeira dobra do cockpit.
2. O hero deve sinalizar Valley como produto, nao apenas como texto pequeno.
3. O fundo pode ser noturno, mas paineis operacionais devem manter leitura clara.
4. Cards continuam funcionais; evitar cards dentro de cards.
5. O MVP deve aparecer como corte operacional, sem esconder o ecossistema V47.

## Regras Para O Super APK Flutter

### Shell

O Super APK deve ter um shell modular com rotas principais:

- Wallet / Pay
- Marketplace
- Business
- Estoque
- Identidade
- Helena

### Splash

Usar a logomarca oficial centralizada sobre fundo `night`.

Regras:

- nao usar texto longo na splash
- nao distorcer a marca
- manter margem segura
- carregar apenas o necessario para primeira sessao

### App Bar

Usar fundo `night` ou `cosmic`, com icone Valley reduzido quando houver espaco.

### Botoes

- Primario: `violet`
- Secundario: borda `cyan`
- Perigo: `danger`
- Sucesso: `success`

### Cartoes

Raio maximo recomendado: 8 para cards de lista, 18 para paineis grandes.

### Identidade

Face ID, Voice ID e Identity Score devem aparecer como camada de confianca, nao como tela promocional.

Superficies esperadas:

- status de verificacao
- score explicavel
- alertas de risco
- historico de revisao

### Helena

Helena deve ser produtiva, leve e controlada por plano.

Regras:

- mostrar limite de uso quando aplicavel
- evitar chat infinito gratuito
- favorecer sugestao acionavel
- registrar consentimento antes de acao sensivel

## Entrega Implementada Agora

- Logomarca oficial copiada para `assets/brand/logo-valley-official.png`
- Logomarca disponibilizada no cockpit em `admin/assets/logo-valley-official.png`
- Hero do cockpit atualizado para usar a marca oficial
- Paleta do cockpit alinhada com Night, Cosmic, Violet e Cyan
- Tokens de marca criados em JSON
- Tema Flutter base criado para futura aplicacao mobile

## Proximo Passo Natural

Quando o projeto Flutter real for criado, declarar no `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/brand/logo-valley-official.png
```

Depois importar:

```dart
import 'lib/valley_brand_theme.dart';
```

E aplicar:

```dart
theme: ValleyBrandTheme.light(),
darkTheme: ValleyBrandTheme.dark(),
```
