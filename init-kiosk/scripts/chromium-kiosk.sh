#!/bin/sh
set -eu

URL="${GBOU_KIOSK_URL:-http://127.0.0.1:8765}"

if command -v xset >/dev/null 2>&1; then
  xset s off >/dev/null 2>&1 || true
  xset -dpms >/dev/null 2>&1 || true
  xset s noblank >/dev/null 2>&1 || true
fi

if command -v chromium >/dev/null 2>&1; then
  CHROMIUM=chromium
elif command -v chromium-browser >/dev/null 2>&1; then
  CHROMIUM=chromium-browser
else
  exit 1
fi

exec "$CHROMIUM" \
  --kiosk \
  --app="$URL" \
  --no-first-run \
  --disable-extensions \
  --disable-sync \
  --disable-translate \
  --disable-background-networking \
  --disable-background-timer-throttling \
  --disable-component-update \
  --disable-default-apps \
  --disable-features=Translate,MediaRouter,OptimizationHints \
  --disable-renderer-backgrounding \
  --disk-cache-size=33554432 \
  --media-cache-size=8388608 \
  --js-flags=--max-old-space-size=192 \
  --password-store=basic \
  --use-mock-keychain \
  --overscroll-history-navigation=0
