# Valley APK Release Blueprint ABI v034

## Escopo

- Artefato: APK Android release split por ABI.
- Base publica: `https://admin.brasildesconto.com.br`
- Dart define obrigatorio: `VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br`
- Build esperado: `flutter build apk --release --split-per-abi`

## Release Gates

- Gerar pelo menos `app-arm64-v8a-release.apk`.
- Validar que o APK foi gerado depois da recomposicao do catalogo STOCK.
- Preferir envio Telegram do APK `arm64-v8a`; se tamanho exceder limite, usar link publico de download.
- Enviar junto os links dos paineis admin e lojista/produto.

## Estado v034

- Cloudflare fixo esta funcional antes do build.
- STOCK carregado com `1089` itens no runtime e no asset embarcado.
- Auto-pause foi desativado somente por override temporario da atividade, sem alterar regra permanente de banco.

## Comando Canonico

```powershell
flutter build apk --release --split-per-abi --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br
```
