# Valley Super App Flutter

Base cross-platform do MVP Valley para Web e Android.

## O que este app entrega

- shell unica para `PAY`, `PLUG`, `DOCS`, `BUSINESS`, `REPLY`, `STOCK`, `WMS`, `MARKETPLACE`, `CHAT`, `ADVISOR` e `AGENDA`
- visual Valley alinhado aos tokens oficiais
- carregamento a partir dos manifestos reais do repo
- build `web --release` e `apk --release`

## Assets empacotados

- `assets/brand/logo-valley-official.png`
- `assets/data/valley_mvp_manifest.v1.json`
- `assets/data/modules_v47.json`
- `assets/data/valley_admin_data.json`

## Comandos

```bash
flutter pub get
dart analyze lib test
flutter test
flutter build web --release
flutter build apk --release
```

## Artefatos esperados

- Web: `build/web/`
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`

## Assinatura Android

- Template versionado: `android/key.properties.example`
- Configuracao local ignorada pelo Git: `android/key.properties`
- Keystore local ignorada pelo Git: `android/app/valley-release.jks`
