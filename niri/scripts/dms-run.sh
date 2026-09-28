#!/usr/bin/env bash
# Starts DankMaterialShell from a patched copy of its UI, and from the stock UI whenever the
# patch no longer applies. The copy is refreshed when DMS is updated or this script changes.
#
# Patch: the notification center is drawn as a strip down to the bottom of the screen
# (fullHeightSurface), so hiding it from screen shares blacked out that whole strip.
# Drawn at its own size, only the panel is blacked out.
set -uo pipefail

SOURCE="/usr/share/quickshell/dms"
PATCHED="${XDG_DATA_HOME:-$HOME/.local/share}/dms-patched"
TARGET="Modules/Notifications/Center/NotificationCenterPopout.qml"
FULL_HEIGHT_LINE='    fullHeightSurface: true'
SIZED_LINE='    fullHeightSurface: false'

run_stock() {
  echo "dms-run: $1; starting the stock UI" >&2
  exec dms run
}

[[ -f "$SOURCE/shell.qml" ]] || run_stock "no DMS UI at $SOURCE"

stamp="$(cat "$SOURCE/VERSION") $(stat -c %Y "$SOURCE/$TARGET") $(sha256sum "$0" | cut -c1-16)"
if [[ "$(cat "$PATCHED/.patch-stamp" 2>/dev/null)" != "$stamp" ]]; then
  staging="$PATCHED.tmp"
  rm -rf "$staging"
  cp -a "$SOURCE" "$staging" || run_stock "could not copy $SOURCE"
  if ! grep -qxF "$FULL_HEIGHT_LINE" "$staging/$TARGET"; then
    rm -rf "$staging"
    run_stock "the patch no longer matches $TARGET"
  fi
  sed -i "s/^$FULL_HEIGHT_LINE\$/$SIZED_LINE/" "$staging/$TARGET"
  printf '%s\n' "$stamp" > "$staging/.patch-stamp"
  rm -rf "$PATCHED"
  mv "$staging" "$PATCHED"
fi

exec dms run --config "$PATCHED"
