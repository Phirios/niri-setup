#!/usr/bin/env python3
"""Remove DMS keybinds replaced by the persistent custom keybind file."""

import argparse
from pathlib import Path


CUSTOM_KEYS = {
    "Mod+T", "Mod+Return", "Mod+M", "Mod+Comma", "Mod+Ctrl+M", "Mod+Ctrl+Comma",
    "Mod+H", "Mod+J", "Mod+K", "Mod+L",
    "Mod+Shift+H", "Mod+Shift+J", "Mod+Shift+K", "Mod+Shift+L",
    "Mod+Ctrl+H", "Mod+Ctrl+J", "Mod+Ctrl+K", "Mod+Ctrl+L",
    "Mod+Shift+Ctrl+H", "Mod+Shift+Ctrl+J", "Mod+Shift+Ctrl+K", "Mod+Shift+Ctrl+L",
    "Mod+U", "Mod+I", "Mod+Ctrl+U", "Mod+Ctrl+I", "Mod+Shift+U", "Mod+Shift+I",
}

LEGACY_KEYS = {
    "Mod+Left", "Mod+Down", "Mod+Up", "Mod+Right",
    "Mod+Shift+Left", "Mod+Shift+Down", "Mod+Shift+Up", "Mod+Shift+Right",
    "Mod+Home", "Mod+End", "Mod+Ctrl+Home", "Mod+Ctrl+End",
    "Mod+Ctrl+Left", "Mod+Ctrl+Down", "Mod+Ctrl+Up", "Mod+Ctrl+Right",
    "Mod+Shift+Ctrl+Left", "Mod+Shift+Ctrl+Down", "Mod+Shift+Ctrl+Up", "Mod+Shift+Ctrl+Right",
    "Mod+Page_Down", "Mod+Page_Up", "Mod+Shift+Page_Down", "Mod+Shift+Page_Up",
}


def without_managed_binds(contents):
    removed = CUSTOM_KEYS | LEGACY_KEYS
    output = []
    skipping_depth = 0

    for line in contents.splitlines(keepends=True):
        if skipping_depth:
            skipping_depth += line.count("{") - line.count("}")
            continue

        stripped = line.lstrip()
        chord = stripped.split(maxsplit=1)[0] if stripped else ""
        if chord in removed:
            skipping_depth = line.count("{") - line.count("}")
            continue

        output.append(line)

    return "".join(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binds_file", type=Path)
    args = parser.parse_args()
    contents = args.binds_file.read_text()
    args.binds_file.write_text(without_managed_binds(contents))


if __name__ == "__main__":
    main()
