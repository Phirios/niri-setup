#!/usr/bin/env bash
# Arranges the tiled windows on the focused workspace into a grid that fills the screen
# exactly: 2 windows side by side, 4 as 2x2, 6 as 3x2, 9 as 3x3. Every window is on screen.
set -euo pipefail

MAX_EXPELS=32

act() { niri msg action "$@" >/dev/null; }

# Tiled windows on the focused workspace as "column row id", in layout order.
tiled_windows() {
  local workspace
  workspace="$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .id')"
  niri msg --json windows | jq -r --argjson ws "$workspace" '
    [.[] | select(.workspace_id == $ws and .is_floating == false
                  and .layout.pos_in_scrolling_layout != null)]
    | sort_by(.layout.pos_in_scrolling_layout)
    | .[] | "\(.layout.pos_in_scrolling_layout[0]) \(.layout.pos_in_scrolling_layout[1]) \(.id)"'
}

original="$(niri msg --json focused-window | jq -r '.id // empty')"

# 1. One window per column, so the pairing below starts from a known shape.
for ((i = 0; i < MAX_EXPELS; i++)); do
  stacked="$(tiled_windows | awk '$2 > 1 { print $3; exit }')"
  [[ -n "$stacked" ]] || break
  act focus-window --id "$stacked"
  act expel-window-from-column
done

mapfile -t ids < <(tiled_windows | awk '{ print $3 }')
count=${#ids[@]}
[[ $count -ge 1 ]] || exit 0

# 2. As many columns as rows or one more: ceil(sqrt(n)) columns of ceil(n / columns) windows.
columns=1
while ((columns * columns < count)); do ((columns++)); done
rows=$(((count + columns - 1) / columns))
width="$(awk -v c="$columns" 'BEGIN { printf "%.4f%%", 100 / c }')"

# 3. Each window that does not start a column joins the column on its left.
for ((i = 0; i < count; i++)); do
  ((i % rows == 0)) && continue
  act focus-window --id "${ids[i]}"
  act consume-or-expel-window-left
done

# 4. Columns share the screen width, windows share each column's height.
for ((i = 0; i < count; i++)); do
  act focus-window --id "${ids[i]}"
  act reset-window-height
  ((i % rows == 0)) && act set-column-width "$width"
done

act focus-window --id "${ids[0]}"
act focus-column-first
[[ -z "$original" ]] || act focus-window --id "$original"
