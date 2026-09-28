#!/usr/bin/env bash
set -euo pipefail

direction="${1:-next}"
case "$direction" in
  next|previous) ;;
  *) printf 'usage: %s [next|previous]\n' "$0" >&2; exit 2 ;;
esac

wallpaper_dir="$HOME/Videos/Wallpapers"
settings_file="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugin_settings.json"
mapfile -d '' -t wallpapers < <(
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
    -print0 | sort -z
)
if ((${#wallpapers[@]} == 0)); then
  printf 'No video wallpapers found in %s\n' "$wallpaper_dir" >&2
  exit 1
fi

current=""
if [[ -f "$settings_file" ]]; then
  current="$(jq -r '.liveWallpaper.videoPath // ""' "$settings_file")"
fi
if [[ "$current" == '~/'* ]]; then
  current="$HOME/${current#\~/}"
fi

current_index=-1
for index in "${!wallpapers[@]}"; do
  if [[ "${wallpapers[$index]}" == "$current" ]]; then
    current_index=$index
    break
  fi
done

if [[ "$direction" == next ]]; then
  selected_index=$(((current_index + 1) % ${#wallpapers[@]}))
elif ((current_index < 0)); then
  selected_index=$((${#wallpapers[@]} - 1))
else
  selected_index=$(((current_index - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]}))
fi

# The plugin IPC updates DMS settings and switches the Qt player together.
dms ipc call liveWallpaper select "${wallpapers[$selected_index]}"
