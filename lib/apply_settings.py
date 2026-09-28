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
# Only visible while the screen is shared. It sits at the end of the centre section, which DMS
# re-centres as it grows; at the start of the right section it ran into the weather pill.
LIVE_WIDGET = "liveMode"
DEFAULT_CENTER_WIDGETS = ("music", "clock", "weather")
DEFAULT_RIGHT_WIDGETS = (
    "systemTray", "clipboard", "cpuUsage", "memUsage", "notificationButton", "battery", "controlCenterButton",
)
DEFAULT_CONTROL_CENTER_WIDGETS = (
    {"id": "volumeSlider", "enabled": True, "width": 50},
    {"id": "brightnessSlider", "enabled": True, "width": 50},
    {"id": "wifi", "enabled": True, "width": 50},
    {"id": "bluetooth", "enabled": True, "width": 50},
    {"id": "audioOutput", "enabled": True, "width": 50},
    {"id": "audioInput", "enabled": True, "width": 50},
    {"id": "nightMode", "enabled": True, "width": 50},
    {"id": "darkMode", "enabled": True, "width": 50},
)
TAILSCALE_WIDGET = {"id": "builtin_tailscale", "enabled": True, "width": 100}
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


def with_live_widget(widgets):
    return widgets if LIVE_WIDGET in widgets else [*widgets, LIVE_WIDGET]


def with_plugin_widgets(widgets):
    """Put the plugin widgets right after the clipboard, or at the end when there is none."""
    widgets = [name for name in widgets if name != LIVE_WIDGET]
    missing = [name for name in PLUGIN_WIDGETS if name not in widgets]
    if "clipboard" not in widgets:
        return [*widgets, *missing]
    split = widgets.index("clipboard") + 1
    return [*widgets[:split], *missing, *widgets[split:]]


def with_tailscale_widget(widgets):
    """Keep the existing Control Center layout and add one full-width Tailscale section."""
    if any(isinstance(widget, dict) and widget.get("id") == TAILSCALE_WIDGET["id"] for widget in widgets):
        return widgets
    return [*widgets, dict(TAILSCALE_WIDGET)]


def merge_shell_settings(current, theme_file):
    current = {**IDLE_DEFAULTS, **current}
    look = {
        "currentThemeName": "custom",
        "currentThemeCategory": "custom",
        "customThemeFile": theme_file,
        "blurEnabled": True,
        # A dimmed backdrop makes DMS draw a modal as one full-screen surface, which the
        # screen-share rules can only black out whole.
        "modalDarkenBackground": False,
        "popupTransparency": POPUP_TRANSPARENCY,
        "controlCenterWidgets": with_tailscale_widget(
            list(current.get("controlCenterWidgets", DEFAULT_CONTROL_CENTER_WIDGETS))
        ),
    }
    bars = current.get("barConfigs")
    if not bars:
        # No bar yet: DMS builds the first one from these keys when it migrates the file.
        return {
            **current,
            **look,
            "dankBarCenterWidgets": with_live_widget(list(current.get("dankBarCenterWidgets", DEFAULT_CENTER_WIDGETS))),
            "dankBarRightWidgets": with_plugin_widgets(list(current.get("dankBarRightWidgets", DEFAULT_RIGHT_WIDGETS))),
            "dankBarTransparency": BAR_TRANSPARENCY,
            "dankBarWidgetTransparency": WIDGET_TRANSPARENCY,
        }

    main_bar = {
        **bars[0],
        "centerWidgets": with_live_widget(list(bars[0].get("centerWidgets", DEFAULT_CENTER_WIDGETS))),
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


def without_comments(values):
    """Profile files may carry "_comment" keys for the people editing them."""
    return {key: value for key, value in values.items() if not key.startswith("_")}


def apply_profile_shell(current, profile):
    """A profile's shell.json: top-level DMS settings, plus "bar" for the main bar's settings."""
    profile = without_comments(profile)
    bar = without_comments(profile.pop("bar", {}))
    merged = {**current, **profile}
    bars = merged.get("barConfigs")
    if not bar:
        return merged
    if not bars:
        # No bar yet: DMS builds the first one from dankBar* keys, e.g. transparency -> dankBarTransparency.
        return {**merged, **{"dankBar" + key[0].upper() + key[1:]: value for key, value in bar.items()}}
    return {**merged, "barConfigs": [{**bars[0], **bar}, *bars[1:]]}


def apply_profile_plugins(current, profile):
    """A profile's plugins.json: settings per plugin id, merged into what is there."""
    profile = without_comments(profile)
    return {
        **current,
        **{plugin: {**current.get(plugin, {}), **without_comments(values)} for plugin, values in profile.items()},
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
    parser.add_argument("--profile-dir", type=Path, help="personal profile with shell.json and plugins.json")
    args = parser.parse_args(argv)

    if not args.theme_file.is_file():
        raise SystemExit(f"theme file not found: {args.theme_file}")
    args.config_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")

    settings_path = args.config_dir / "settings.json"
    plugins_path = args.config_dir / "plugin_settings.json"
    profile_shell = read_json(args.profile_dir / "shell.json") if args.profile_dir else {}
    profile_plugins = read_json(args.profile_dir / "plugins.json") if args.profile_dir else {}

    shell = merge_shell_settings(read_json(settings_path), str(args.theme_file))
    write_json(settings_path, apply_profile_shell(shell, profile_shell), stamp)
    wallpaper = str(args.wallpaper) if args.wallpaper else None
    plugins = merge_plugin_settings(read_json(plugins_path), wallpaper, args.voice)
    plugins = apply_profile_plugins(plugins, profile_plugins)
    if wallpaper:
        # A video given on the command line beats the one in the profile.
        plugins = apply_profile_plugins(plugins, {"liveWallpaper": {"videoPath": wallpaper}})
    write_json(plugins_path, plugins, stamp)


if __name__ == "__main__":
    main(sys.argv[1:])
