#!/usr/bin/env bash
# Toggle "show desktop": jump to the empty workspace niri keeps at the end of the
# focused output, and jump back to where you were when pressed again.
set -euo pipefail

workspaces="$(niri msg --json workspaces)"
focused="$(jq -c '.[] | select(.is_focused)' <<<"$workspaces")"

if [[ -z "$focused" ]]; then
  echo "show-desktop: no focused workspace" >&2
  exit 1
fi

if [[ "$(jq -r '.active_window_id' <<<"$focused")" == "null" ]]; then
  niri msg action focus-workspace-previous
  exit 0
fi

output="$(jq -r '.output' <<<"$focused")"
empty_idx="$(jq -r --arg output "$output" \
  '[.[] | select(.output == $output)] | max_by(.idx) | .idx' <<<"$workspaces")"
niri msg action focus-workspace "$empty_idx"
