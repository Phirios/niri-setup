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
PICKER_TARGET="Modules/DankDash/WallpaperTab.qml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICKER_PATCH="$SCRIPT_DIR/dms-wallpaper-picker.patch"
THUMBNAIL_HELPER="$HOME/.local/bin/dms-live-wallpaper-thumbnails"
FULL_HEIGHT_LINE='    fullHeightSurface: true'
SIZED_LINE='    fullHeightSurface: false'

run_stock() {
  echo "dms-run: $1; starting the stock UI" >&2
  exec dms run
}

[[ -f "$SOURCE/shell.qml" ]] || run_stock "no DMS UI at $SOURCE"
[[ -f "$PICKER_PATCH" ]] || run_stock "no wallpaper picker patch at $PICKER_PATCH"

stamp="$(cat "$SOURCE/VERSION") $(stat -c %Y "$SOURCE/$TARGET" "$SOURCE/$PICKER_TARGET") $(sha256sum "$0" "$PICKER_PATCH" | cut -c1-16)"
if [[ "$(cat "$PATCHED/.patch-stamp" 2>/dev/null)" != "$stamp" ]]; then
  staging="$PATCHED.tmp"
  rm -rf "$staging"
  cp -a "$SOURCE" "$staging" || run_stock "could not copy $SOURCE"
  if ! grep -qxF "$FULL_HEIGHT_LINE" "$staging/$TARGET"; then
    rm -rf "$staging"
    run_stock "the patch no longer matches $TARGET"
  fi
  sed -i "s/^$FULL_HEIGHT_LINE\$/$SIZED_LINE/" "$staging/$TARGET"
  if ! patch --silent -p1 -d "$staging" < "$PICKER_PATCH"; then
    rm -rf "$staging"
    run_stock "the wallpaper picker patch no longer matches $PICKER_TARGET"
  fi
  printf '%s\n' "$stamp" > "$staging/.patch-stamp"
  rm -rf "$PATCHED"
  mv "$staging" "$PATCHED"
fi

if [[ -x "$THUMBNAIL_HELPER" ]] && ! "$THUMBNAIL_HELPER"; then
  echo "dms-run: could not refresh live wallpaper thumbnails" >&2
fi

exec dms run --config "$PATCHED"
