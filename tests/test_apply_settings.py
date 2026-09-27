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
        self.assertIn("aiLimitCounter", merged["dankBarRightWidgets"])
        self.assertIn("dmsAgent", merged["dankBarRightWidgets"])
        self.assertEqual(merged["dankBarRightWidgets"][0], "liveMode")
        self.assertEqual(merged["dankBarTransparency"], 0.55)
        self.assertNotIn("barConfigs", merged)

    def test_existing_bar_gets_the_widgets_next_to_the_clipboard(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["systemTray", "clipboard", "battery"]}]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(
            bar["rightWidgets"], ["liveMode", "systemTray", "clipboard", "aiLimitCounter", "dmsAgent", "battery"])
        self.assertEqual(bar["transparency"], 0.55)
        self.assertEqual(bar["widgetTransparency"], 0.5)

    def test_widgets_are_appended_when_there_is_no_clipboard(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["battery"]}]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(bar["rightWidgets"], ["liveMode", "battery", "aiLimitCounter", "dmsAgent"])

    def test_running_twice_does_not_duplicate_widgets(self):
        once = merge_shell_settings({"barConfigs": [{"id": "default", "rightWidgets": ["clipboard"]}]}, THEME)

        twice = merge_shell_settings(once, THEME)

        self.assertEqual(twice["barConfigs"][0]["rightWidgets"].count("dmsAgent"), 1)
        self.assertEqual(twice["barConfigs"][0]["rightWidgets"].count("liveMode"), 1)
        self.assertEqual(twice, once)

    def test_other_bars_and_settings_are_kept(self):
        current = {
            "cornerRadius": 8,
            "barConfigs": [{"id": "default", "rightWidgets": []}, {"id": "second", "rightWidgets": ["clock"]}],
        }

        merged = merge_shell_settings(current, THEME)

        self.assertEqual(merged["cornerRadius"], 8)
        self.assertEqual(merged["barConfigs"][1], {"id": "second", "rightWidgets": ["clock"]})

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
        self.assertFalse(merged["dmsAgent"]["autoUpdate"])
        self.assertFalse(merged["dmsAgent"]["voiceEnabled"])

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


if __name__ == "__main__":
    unittest.main()
