#!/usr/bin/env python3
"""Merge the Ink look and the two plugins into a DankMaterialShell config directory.

Existing settings are kept; only the keys this setup owns are changed. Files that are
replaced get a timestamped backup next to them.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

PLUGIN_WIDGETS = ("aiLimitCounter", "dmsAgent")
# Only visible while the screen is shared; first, so it never shifts the widgets next to it.
LEADING_WIDGET = "liveMode"
DEFAULT_RIGHT_WIDGETS = (
    "systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton",
)
BAR_TRANSPARENCY = 0.7
# Opaque enough that each bar item reads as its own pill over a busy wallpaper.
WIDGET_TRANSPARENCY = 0.9
POPUP_TRANSPARENCY = 0.78
# Seconds. Only filled in when missing, so timeouts chosen in the settings survive a re-run.
IDLE_DEFAULTS = {
    "acLockTimeout": 900, "acMonitorTimeout": 1800,
    "batteryLockTimeout": 300, "batteryMonitorTimeout": 600,
    "lockBeforeSuspend": True,
    # Shows the new profile when Super+B cycles it.
    "osdPowerProfileEnabled": True,
}

AGENT_DEFAULTS = {"enabled": True, "claudeModel": "haiku", "pillLabel": "Claude", "backgroundOpacity": 80}
LIVE_DEFAULTS = {"silenceNotifications": True, "keepAwake": True}
# Without a video the plugin does nothing; it is chosen in the settings or with --wallpaper.
WALLPAPER_DEFAULTS = {
    "videoPath": "", "pauseWhenHidden": True, "stopOnBattery": True, "stopWhileGaming": True,
}
# New code and an open microphone are opt-in, whatever was configured before.
AGENT_SAFETY = {"autoUpdate": False, "voiceEnabled": False}


def with_plugin_widgets(widgets):
    """Put the plugin widgets right after the clipboard, or at the end when there is none."""
    if LEADING_WIDGET not in widgets:
        widgets = [LEADING_WIDGET, *widgets]
    missing = [name for name in PLUGIN_WIDGETS if name not in widgets]
    if "clipboard" not in widgets:
        return [*widgets, *missing]
    split = widgets.index("clipboard") + 1
    return [*widgets[:split], *missing, *widgets[split:]]


def merge_shell_settings(current, theme_file):
    current = {**IDLE_DEFAULTS, **current}
    look = {
        "currentThemeName": "custom",
        "currentThemeCategory": "custom",
        "customThemeFile": theme_file,
        "blurEnabled": True,
        "popupTransparency": POPUP_TRANSPARENCY,
    }
    bars = current.get("barConfigs")
    if not bars:
        # No bar yet: DMS builds the first one from these keys when it migrates the file.
        return {
            **current,
            **look,
            "dankBarRightWidgets": with_plugin_widgets(list(current.get("dankBarRightWidgets", DEFAULT_RIGHT_WIDGETS))),
            "dankBarTransparency": BAR_TRANSPARENCY,
            "dankBarWidgetTransparency": WIDGET_TRANSPARENCY,
        }

    main_bar = {
        **bars[0],
        "rightWidgets": with_plugin_widgets(list(bars[0].get("rightWidgets", []))),
        "transparency": BAR_TRANSPARENCY,
        "widgetTransparency": WIDGET_TRANSPARENCY,
    }
    return {**current, **look, "barConfigs": [main_bar, *bars[1:]]}


def merge_plugin_settings(current, wallpaper=None, voice=False):
    chosen_video = {"videoPath": wallpaper} if wallpaper else {}
    # Voice only works once the installer has set up Whisper, so only then is it switched on.
    safety = {**AGENT_SAFETY, "voiceEnabled": voice}
    return {
        **current,
        "aiLimitCounter": {"provider": "claude", **current.get("aiLimitCounter", {}), "enabled": True},
        "dmsAgent": {**AGENT_DEFAULTS, **current.get("dmsAgent", {}), "enabled": True, **safety},
        "liveMode": {**LIVE_DEFAULTS, **current.get("liveMode", {}), "enabled": True},
        "liveWallpaper": {
            **WALLPAPER_DEFAULTS, **current.get("liveWallpaper", {}), **chosen_video, "enabled": True,
        },
    }


def read_json(path):
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"cannot read {path}: {error}") from error
    if not isinstance(data, dict):
        raise SystemExit(f"{path} does not contain a JSON object")
    return data


def write_json(path, data, stamp):
    if path.exists():
        backup = path.with_name(f"{path.name}.bak-{stamp}")
        backup.write_bytes(path.read_bytes())
        print(f"  backed up {path.name} to {backup.name}")
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(data, indent=2) + "\n")
    os.replace(temporary, path)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-dir", required=True, type=Path, help="DankMaterialShell config directory")
    parser.add_argument("--theme-file", required=True, type=Path, help="installed location of ink.json")
    parser.add_argument("--wallpaper", type=Path, help="video for the live wallpaper")
    parser.add_argument("--voice", action="store_true", help="switch on voice input in the chat panel")
    args = parser.parse_args(argv)

    if not args.theme_file.is_file():
        raise SystemExit(f"theme file not found: {args.theme_file}")
    args.config_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")

    settings_path = args.config_dir / "settings.json"
    plugins_path = args.config_dir / "plugin_settings.json"
    write_json(settings_path, merge_shell_settings(read_json(settings_path), str(args.theme_file)), stamp)
    wallpaper = str(args.wallpaper) if args.wallpaper else None
    write_json(plugins_path, merge_plugin_settings(read_json(plugins_path), wallpaper, args.voice), stamp)


if __name__ == "__main__":
    main(sys.argv[1:])
