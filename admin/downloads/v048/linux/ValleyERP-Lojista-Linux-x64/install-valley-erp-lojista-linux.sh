#!/usr/bin/env bash
set -euo pipefail

APP_ID="valley-erp-lojista"
APP_NAME="Valley ERP Lojista"
API_BASE_URL="${VALLEY_PRODUCT_API_BASE_URL:-https://admin.brasildesconto.com.br}"
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/$APP_ID}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/.local/share/applications}"
SOURCE_ROOT="${SOURCE_ROOT:-}"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

if [ -x "$PACKAGE_DIR/app/valley_erp_lojista" ] || [ -x "$PACKAGE_DIR/app/valley_super_app" ]; then
  cp -R "$PACKAGE_DIR/app/." "$INSTALL_DIR/"
elif [ -n "$SOURCE_ROOT" ] && [ -d "$SOURCE_ROOT/frontend/flutter" ]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Flutter nao encontrado. Instale Flutter Linux Desktop ou forneca app/ precompilado." >&2
    exit 2
  fi
  (
    cd "$SOURCE_ROOT/frontend/flutter"
    flutter config --enable-linux-desktop
    flutter pub get
    flutter build linux --release --target lib/merchant_erp_desktop_main.dart --dart-define=VALLEY_PRODUCT_API_BASE_URL="$API_BASE_URL"
  )
  rm -rf "$INSTALL_DIR"/*
  cp -R "$SOURCE_ROOT/frontend/flutter/build/linux/x64/release/bundle/." "$INSTALL_DIR/"
else
  echo "Binario Linux nao incluido neste pacote Windows-hosted." >&2
  echo "Execute com SOURCE_ROOT=/caminho/para/VALLEY para compilar no Linux." >&2
  exit 2
fi

EXECUTABLE="$INSTALL_DIR/valley_erp_lojista"
if [ ! -x "$EXECUTABLE" ] && [ -x "$INSTALL_DIR/valley_super_app" ]; then
  EXECUTABLE="$INSTALL_DIR/valley_super_app"
fi
if [ ! -x "$EXECUTABLE" ]; then
  echo "Executavel nao encontrado em $INSTALL_DIR." >&2
  exit 3
fi

cat > "$BIN_DIR/$APP_ID" <<EOF
#!/usr/bin/env bash
export VALLEY_PRODUCT_API_BASE_URL="$API_BASE_URL"
cd "$INSTALL_DIR"
exec "$EXECUTABLE" "\$@"
EOF
chmod +x "$BIN_DIR/$APP_ID"

cat > "$DESKTOP_DIR/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=ERP Lojista Valley
Exec=$BIN_DIR/$APP_ID
Terminal=false
Categories=Office;Finance;
EOF

echo "$APP_NAME instalado em: $INSTALL_DIR"
echo "Comando: $BIN_DIR/$APP_ID"