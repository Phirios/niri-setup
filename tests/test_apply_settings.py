"""Run with: python3 -m unittest discover -s tests"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))

from apply_settings import merge_plugin_settings, merge_shell_settings  # noqa: E402

THEME = "/home/someone/.config/DankMaterialShell/themes/ink.json"


class ShellSettingsTest(unittest.TestCase):
    def test_fresh_install_uses_keys_dms_migrates_into_a_bar(self):
        merged = merge_shell_settings({}, THEME)

        self.assertEqual(merged["currentThemeName"], "custom")
        self.assertEqual(merged["customThemeFile"], THEME)
        self.assertTrue(merged["blurEnabled"])
        self.assertFalse(merged["modalDarkenBackground"])
        self.assertIn("aiLimitCounter", merged["dankBarRightWidgets"])
        self.assertIn("dmsAgent", merged["dankBarRightWidgets"])
        self.assertEqual(merged["dankBarRightWidgets"][0], "liveMode")
        self.assertEqual(merged["dankBarTransparency"], 0.7)
        self.assertEqual(merged["dankBarWidgetTransparency"], 0.9)
        self.assertEqual(merged["controlCenterWidgets"][-1], {
            "id": "builtin_tailscale", "enabled": True, "width": 100,
        })
        self.assertNotIn("barConfigs", merged)

    def test_existing_bar_gets_the_widgets_next_to_the_clipboard(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["systemTray", "clipboard", "battery"]}]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(
            bar["rightWidgets"], ["liveMode", "systemTray", "clipboard", "aiLimitCounter", "dmsAgent", "battery"])
        self.assertEqual(bar["transparency"], 0.7)
        self.assertEqual(bar["widgetTransparency"], 0.9)

    def test_widgets_are_appended_when_there_is_no_clipboard(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["battery"]}]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(bar["rightWidgets"], ["liveMode", "battery", "aiLimitCounter", "dmsAgent"])

    def test_running_twice_does_not_duplicate_widgets(self):
        once = merge_shell_settings({"barConfigs": [{"id": "default", "rightWidgets": ["clipboard"]}]}, THEME)

        twice = merge_shell_settings(once, THEME)

        self.assertEqual(twice["barConfigs"][0]["rightWidgets"].count("dmsAgent"), 1)
        self.assertEqual(twice["barConfigs"][0]["rightWidgets"].count("liveMode"), 1)
        self.assertEqual(
            sum(widget.get("id") == "builtin_tailscale" for widget in twice["controlCenterWidgets"]), 1)
        self.assertEqual(twice, once)

    def test_existing_control_center_layout_is_kept_and_gets_tailscale(self):
        current = {
            "controlCenterWidgets": [
                {"id": "wifi", "enabled": True, "width": 25},
                {"id": "darkMode", "enabled": False, "width": 50},
            ]
        }

        merged = merge_shell_settings(current, THEME)

        self.assertEqual(merged["controlCenterWidgets"][:-1], current["controlCenterWidgets"])
        self.assertEqual(merged["controlCenterWidgets"][-1], {
            "id": "builtin_tailscale", "enabled": True, "width": 100,
        })

    def test_other_bars_and_settings_are_kept(self):
        current = {
            "cornerRadius": 8,
            "barConfigs": [{"id": "default", "rightWidgets": []}, {"id": "second", "rightWidgets": ["clock"]}],
        }

        merged = merge_shell_settings(current, THEME)

        self.assertEqual(merged["cornerRadius"], 8)
        self.assertEqual(merged["barConfigs"][1], {"id": "second", "rightWidgets": ["clock"]})

    def test_fresh_install_gets_the_idle_and_lock_timeouts(self):
        merged = merge_shell_settings({}, THEME)

        self.assertEqual(merged["acLockTimeout"], 900)
        self.assertEqual(merged["acMonitorTimeout"], 1800)
        self.assertEqual(merged["batteryLockTimeout"], 300)
        self.assertEqual(merged["batteryMonitorTimeout"], 600)
        self.assertTrue(merged["lockBeforeSuspend"])
        self.assertTrue(merged["osdPowerProfileEnabled"])

    def test_idle_timeouts_already_chosen_are_kept(self):
        merged = merge_shell_settings({"acLockTimeout": 60, "lockBeforeSuspend": False}, THEME)

        self.assertEqual(merged["acLockTimeout"], 60)
        self.assertFalse(merged["lockBeforeSuspend"])

    def test_input_is_not_modified(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["clipboard"]}]}

        merge_shell_settings(current, THEME)

        self.assertEqual(current, {"barConfigs": [{"id": "default", "rightWidgets": ["clipboard"]}]})


class PluginSettingsTest(unittest.TestCase):
    def test_enables_both_plugins_with_safe_agent_defaults(self):
        merged = merge_plugin_settings({})

        self.assertTrue(merged["aiLimitCounter"]["enabled"])
        self.assertTrue(merged["dmsAgent"]["enabled"])
        self.assertTrue(merged["liveMode"]["enabled"])
        self.assertTrue(merged["liveWallpaper"]["enabled"])
        self.assertEqual(merged["liveWallpaper"]["videoPath"], "")
        self.assertTrue(merged["liveWallpaper"]["stopWhileGaming"])
        self.assertFalse(merged["dmsAgent"]["autoUpdate"])
        self.assertFalse(merged["dmsAgent"]["voiceEnabled"])

    def test_a_chosen_wallpaper_video_is_kept(self):
        merged = merge_plugin_settings({"liveWallpaper": {"videoPath": "~/Videos/loop.webm"}})

        self.assertEqual(merged["liveWallpaper"]["videoPath"], "~/Videos/loop.webm")

    def test_a_wallpaper_given_to_the_installer_replaces_the_old_one(self):
        merged = merge_plugin_settings({"liveWallpaper": {"videoPath": "~/old.webm"}}, "/home/me/new.webm")

        self.assertEqual(merged["liveWallpaper"]["videoPath"], "/home/me/new.webm")

    def test_choices_already_made_are_kept_except_the_safety_switches(self):
        current = {
            "aiLimitCounter": {"enabled": True, "provider": "codex"},
            "dmsAgent": {"claudeModel": "sonnet", "autoUpdate": True},
            "somethingElse": {"enabled": False},
        }

        merged = merge_plugin_settings(current)

        self.assertEqual(merged["aiLimitCounter"]["provider"], "codex")
        self.assertEqual(merged["dmsAgent"]["claudeModel"], "sonnet")
        self.assertFalse(merged["dmsAgent"]["autoUpdate"])
        self.assertEqual(merged["somethingElse"], {"enabled": False})

    def test_voice_stays_off_unless_the_installer_set_it_up(self):
        merged = merge_plugin_settings({"dmsAgent": {"voiceEnabled": True}})

        self.assertFalse(merged["dmsAgent"]["voiceEnabled"])

    def test_voice_is_switched_on_when_the_installer_set_it_up(self):
        merged = merge_plugin_settings({}, voice=True)

        self.assertTrue(merged["dmsAgent"]["voiceEnabled"])
        self.assertFalse(merged["dmsAgent"]["autoUpdate"])


if __name__ == "__main__":
    unittest.main()
