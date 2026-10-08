# Directional window growth

Super + Ctrl + H/J/K/L grows the focused tiled window left/down/up/right.
Add Shift to shrink toward left/down/up/right, retracting the opposite edge
to the next smaller fraction. For example, Shift+H retracts the right edge.
Add Alt (Super + Ctrl + Alt + H/J/K/L) to take the whole neighbouring span
immediately, provided the neighbour can retain a rectangle at least 200 px wide
and high above/below or to the side. Otherwise the operation is refused.

Each press grows the focused window to the next larger fraction of the space
shared with its adjacent neighbour: 1/5 → 1/4 → 1/3 → 1/2 → 2/3 → 3/4 → 4/5.
The fractions apply to tile space; Hyprland applies gaps and borders afterwards.
Targets that would make an affected window's content width or height smaller
than 200 px are refused, instead of stopping at an arbitrary pixel width.

After 4/5, taking the whole row/column is possible if the neighbour can retain
a rectangular strip above/below (or left/right of) the focused window. Its
content must still be at least 200 px in both dimensions. This preserves the
neighbour reshaping behaviour instead of removing the neighbour.

Otherwise only windows whose shared edges overlap participate. Windows in the
row above/below that merely meet the divider at an endpoint stay unchanged.
A neighbour spanning several rows still connects those rows when they must
move together to keep every window rectangular. Configurations that cannot fit into Dwindle's binary tree,
grouped windows, fullscreen windows, and asymmetric gaps are refused. Floating
windows are untouched. The current Dwindle layout and ordinary mouse resizing
remain available.

The native tree is rebuilt in a single Lua IPC evaluation. Tiled windows are
temporarily detached using floating mode, staying visible on the same workspace;
no window is parked in a hidden workspace. They are tiled again before that
evaluation finishes. Window addresses, processes, and contents remain the same.
Observed coordinates are checked after every operation. A failed operation
attempts to restore the previous geometry. The helper refuses to apply a plan
if the windows changed while it was calculating.

Preview without changing windows:

```sh
hypr-smart-resize right --dry-run
```

Restore the last successful resize (only if those windows still match its result):

```sh
hypr-smart-resize undo
```

Pure geometry tests:

```sh
cd ~/.local/share/hypr-smart-resize
python3 -m unittest -v test_resize.py
```

Bindings are in ~/.config/hypr/custom/smart-resize.lua, loaded from hyprland.lua.
Remove that require line and reload the configuration to disable the shortcuts.
