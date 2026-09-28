#!/usr/bin/env bash
# Arranges the tiled windows on the focused workspace into a grid: columns of two windows
# stacked on top of each other, each column half the screen wide. Four windows make a 2x2.
set -euo pipefail

COLUMN_WIDTH="50%"
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
[[ ${#ids[@]} -ge 2 ]] || exit 0

# 2. Every second window joins the column on its left.
for ((i = 1; i < ${#ids[@]}; i += 2)); do
  act focus-window --id "${ids[i]}"
  act consume-or-expel-window-left
done

# 3. Half-width columns, windows sharing each column's height equally.
for ((i = 0; i < ${#ids[@]}; i++)); do
  act focus-window --id "${ids[i]}"
  act reset-window-height
  ((i % 2 == 0)) && act set-column-width "$COLUMN_WIDTH"
done

act focus-window --id "${ids[0]}"
[[ -z "$original" ]] || act focus-window --id "$original"
