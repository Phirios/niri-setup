"""Run with: python3 -m unittest discover -s tests"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))

from apply_settings import (  # noqa: E402
    apply_profile_plugins,
    apply_profile_shell,
    merge_plugin_settings,
    merge_shell_settings,
)

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
        self.assertNotIn("liveMode", merged["dankBarRightWidgets"])
        self.assertEqual(merged["dankBarCenterWidgets"], ["music", "clock", "weather", "liveMode"])
        self.assertEqual(merged["dankBarTransparency"], 0.7)
        self.assertEqual(merged["dankBarWidgetTransparency"], 0.9)
        self.assertNotIn("barConfigs", merged)

    def test_existing_bar_gets_the_widgets_next_to_the_clipboard(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["systemTray", "clipboard", "battery"]}]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(bar["rightWidgets"], ["systemTray", "clipboard", "aiLimitCounter", "dmsAgent", "battery"])
        self.assertEqual(bar["transparency"], 0.7)
        self.assertEqual(bar["widgetTransparency"], 0.9)

    def test_widgets_are_appended_when_there_is_no_clipboard(self):
        current = {"barConfigs": [{"id": "default", "rightWidgets": ["battery"]}]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(bar["rightWidgets"], ["battery", "aiLimitCounter", "dmsAgent"])

    def test_running_twice_does_not_duplicate_widgets(self):
        once = merge_shell_settings({"barConfigs": [{"id": "default", "rightWidgets": ["clipboard"]}]}, THEME)

        twice = merge_shell_settings(once, THEME)

        self.assertEqual(twice["barConfigs"][0]["rightWidgets"].count("dmsAgent"), 1)
        self.assertEqual(twice["barConfigs"][0]["centerWidgets"].count("liveMode"), 1)
        self.assertEqual(twice, once)

    def test_live_pill_moves_from_the_right_to_the_center(self):
        current = {"barConfigs": [{
            "id": "default", "centerWidgets": ["clock"], "rightWidgets": ["liveMode", "clipboard"],
        }]}

        bar = merge_shell_settings(current, THEME)["barConfigs"][0]

        self.assertEqual(bar["centerWidgets"], ["clock", "liveMode"])
        self.assertEqual(bar["rightWidgets"], ["clipboard", "aiLimitCounter", "dmsAgent"])

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



class ProfileTest(unittest.TestCase):
    BASE = {"cornerRadius": 16, "barConfigs": [{"id": "default", "transparency": 0.7, "rightWidgets": ["clock"]}]}

    def test_an_empty_profile_changes_nothing(self):
        self.assertEqual(apply_profile_shell(self.BASE, {}), self.BASE)
        self.assertEqual(apply_profile_plugins({"liveMode": {"enabled": True}}, {}), {"liveMode": {"enabled": True}})

    def test_profile_values_win_over_the_shared_ones(self):
        merged = apply_profile_shell(self.BASE, {"cornerRadius": 8, "acLockTimeout": 600})

        self.assertEqual(merged["cornerRadius"], 8)
        self.assertEqual(merged["acLockTimeout"], 600)

    def test_bar_values_go_into_the_main_bar_and_keep_the_rest_of_it(self):
        merged = apply_profile_shell(self.BASE, {"bar": {"transparency": 1.0}})

        self.assertEqual(merged["barConfigs"][0]["transparency"], 1.0)
        self.assertEqual(merged["barConfigs"][0]["rightWidgets"], ["clock"])
        self.assertNotIn("bar", merged)

    def test_bar_values_before_any_bar_exists_use_the_migration_keys(self):
        merged = apply_profile_shell({"dankBarTransparency": 0.7}, {"bar": {"transparency": 1.0}})

        self.assertEqual(merged["dankBarTransparency"], 1.0)
        self.assertNotIn("barConfigs", merged)

    def test_plugin_values_are_merged_per_plugin(self):
        current = {"liveWallpaper": {"enabled": True, "videoPath": "", "stopOnBattery": True}}

        merged = apply_profile_plugins(current, {"liveWallpaper": {"videoPath": "~/v.webm"}})

        self.assertEqual(merged["liveWallpaper"], {"enabled": True, "videoPath": "~/v.webm", "stopOnBattery": True})

    def test_comment_keys_in_profile_files_are_ignored(self):
        merged = apply_profile_shell(self.BASE, {"_comment": "notes for people", "bar": {"_comment": "x"}})

        self.assertEqual(merged, self.BASE)

    def test_inputs_are_not_modified(self):
        base = {"barConfigs": [{"id": "default", "transparency": 0.7}]}
        apply_profile_shell(base, {"bar": {"transparency": 1.0}})

        self.assertEqual(base, {"barConfigs": [{"id": "default", "transparency": 0.7}]})


if __name__ == "__main__":
    unittest.main()
