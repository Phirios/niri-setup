"""Run with: python3 -m unittest discover -s tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))

from apply_niri_binds import without_managed_binds  # noqa: E402


class NiriBindsTest(unittest.TestCase):
    def test_removes_generated_duplicates_and_legacy_navigation(self):
        source = """binds {
    Mod+T { spawn \"ghostty\"; }
    Mod+M hotkey-overlay-title=\"Task Manager\" {
        spawn \"dms\" \"ipc\" \"call\" \"processlist\" \"focusOrToggle\";
    }
    Mod+Left { focus-column-left; }
    Mod+Page_Down { focus-workspace-down; }
    Mod+Q { close-window; }
}
"""

        self.assertEqual(without_managed_binds(source), """binds {
    Mod+Q { close-window; }
}
""")

    def test_keeps_unrelated_bindings_unchanged(self):
        source = "binds {\n    Mod+Q { close-window; }\n}\n"

        self.assertEqual(without_managed_binds(source), source)


if __name__ == "__main__":
    unittest.main()
