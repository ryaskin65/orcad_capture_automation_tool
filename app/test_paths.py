"""Tests for the pure `paths` module (no GUI/OrCAD dependencies)."""

import os
import sys
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _candidate in (os.path.join(_REPO_ROOT, "app"), _REPO_ROOT):
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

import paths  # noqa: E402


class TestPaths(unittest.TestCase):
    def test_scripts_dir_is_under_app_root(self):
        root = paths.app_root_dir()
        self.assertEqual(paths.scripts_dir(), os.path.join(root, "scripts"))
        self.assertEqual(os.path.dirname(paths.scripts_dir()), root)

    def test_data_dir_is_under_app_root(self):
        root = paths.app_root_dir()
        self.assertEqual(paths.data_dir(), os.path.join(root, "data"))

    def test_script_and_data_path_join_filename(self):
        self.assertEqual(
            paths.script_path("cable.tcl"),
            os.path.join(paths.scripts_dir(), "cable.tcl"),
        )
        self.assertEqual(
            paths.data_path("cable.csv"),
            os.path.join(paths.data_dir(), "cable.csv"),
        )

    def test_app_root_is_absolute(self):
        self.assertTrue(os.path.isabs(paths.app_root_dir()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
