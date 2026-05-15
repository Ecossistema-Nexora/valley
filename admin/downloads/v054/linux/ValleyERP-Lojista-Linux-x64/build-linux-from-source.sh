#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
export VALLEY_PRODUCT_API_BASE_URL="${VALLEY_PRODUCT_API_BASE_URL:-https://admin.brasildesconto.com.br}"

cd "$REPO_ROOT/frontend/flutter"
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release --target lib/merchant_erp_desktop_main.dart --dart-define=VALLEY_PRODUCT_API_BASE_URL="$VALLEY_PRODUCT_API_BASE_URL"

echo "Bundle gerado em: $REPO_ROOT/frontend/flutter/build/linux/x64/release/bundle"