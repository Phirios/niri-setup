#!/usr/bin/env python3
"""Grid layout for the focused niri workspace.

    grid.py           remember the current layout, then fit every tiled window on screen as a
                      grid: 2 side by side, 4 as 2x2, 6 as 3x2, 9 as 3x3
    grid.py restore   put back the layout remembered by the last grid.py on this workspace

A restore is skipped when windows were opened or closed since, because the remembered
layout no longer describes them.
"""
import json
import math
import os
import subprocess
import sys
from pathlib import Path

MAX_EXPELS = 32
STATE_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "niri-grid"


def niri_json(*args):
    output = subprocess.run(["niri", "msg", "--json", *args], check=True, capture_output=True, text=True)
    return json.loads(output.stdout)


def act(*args):
    subprocess.run(["niri", "msg", "action", *args], check=True, capture_output=True)


def focused_workspace():
    return next(ws["id"] for ws in niri_json("workspaces") if ws["is_focused"])


def tiled_windows(workspace):
    """Tiled windows of a workspace in layout order: column by column, top to bottom."""
    windows = [
        w for w in niri_json("windows")
        if w["workspace_id"] == workspace and not w["is_floating"]
        and w["layout"].get("pos_in_scrolling_layout") is not None
    ]
    return sorted(windows, key=lambda w: w["layout"]["pos_in_scrolling_layout"])


def snapshot(windows):
    """Columns as lists of {id, width, height}, enough to rebuild the layout."""
    columns = {}
    for w in windows:
        column, _row = w["layout"]["pos_in_scrolling_layout"]
        width, height = w["layout"]["window_size"]
        columns.setdefault(column, []).append({"id": w["id"], "width": width, "height": height})
    return [columns[c] for c in sorted(columns)]


def one_window_per_column(workspace):
    for _ in range(MAX_EXPELS):
        stacked = next((w for w in tiled_windows(workspace) if w["layout"]["pos_in_scrolling_layout"][1] > 1), None)
        if stacked is None:
            return
        act("focus-window", "--id", str(stacked["id"]))
        act("expel-window-from-column")


def group_into_columns(groups):
    """Windows are one per column, in order; merge each group into one column."""
    for group in groups:
        for window_id in group[1:]:
            act("focus-window", "--id", str(window_id))
            act("consume-or-expel-window-left")


def grid_groups(ids):
    columns = math.ceil(math.sqrt(len(ids)))
    rows = math.ceil(len(ids) / columns)
    return [ids[i:i + rows] for i in range(0, len(ids), rows)], columns


def make_grid(workspace, ids):
    one_window_per_column(workspace)
    groups, columns = grid_groups(ids)
    group_into_columns(groups)
    for group in groups:
        for window_id in group:
            act("focus-window", "--id", str(window_id))
            act("reset-window-height")
        act("set-column-width", f"{100 / columns:.4f}%")


def restore(workspace, columns):
    one_window_per_column(workspace)
    group_into_columns([[w["id"] for w in column] for column in columns])
    for column in columns:
        act("focus-window", "--id", str(column[0]["id"]))
        act("set-column-width", str(column[0]["width"]))
        for window in column:
            act("focus-window", "--id", str(window["id"]))
            act("set-window-height", str(window["height"]))


def load_state(state_file):
    try:
        return json.loads(state_file.read_text())
    except (OSError, json.JSONDecodeError):
        return None


def main(command):
    workspace = focused_workspace()
    windows = tiled_windows(workspace)
    if not windows:
        return
    focused = niri_json("focused-window")
    ids = [w["id"] for w in windows]
    state_file = STATE_DIR / f"{workspace}.json"

    if command == "restore":
        saved = load_state(state_file)
        if not saved or sorted(saved["ids"]) != sorted(ids):
            return
        restore(workspace, saved["columns"])
    else:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        # A grid of a grid would overwrite the layout worth going back to.
        if not load_state(state_file) or grid_groups(ids)[0] != [[w["id"] for w in c] for c in snapshot(windows)]:
            state_file.write_text(json.dumps({"ids": ids, "columns": snapshot(windows)}))
        make_grid(workspace, ids)
        act("focus-window", "--id", str(ids[0]))
        act("focus-column-first")

    if focused:
        act("focus-window", "--id", str(focused["id"]))


if __name__ == "__main__":
    try:
        main(sys.argv[1] if len(sys.argv) > 1 else "grid")
    except subprocess.CalledProcessError as error:
        sys.exit(f"grid: niri refused {error.cmd}: {error.stderr.strip() if error.stderr else ''}")
