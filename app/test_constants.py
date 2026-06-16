"""Guard tests for shared constants.

The completion marker and execution-time prefix are a contract shared with the
TCL scripts in scripts/. These tests pin the values so they cannot be changed
on the Python side alone without a deliberate, visible test update (which is
the signal to also update every TCL script that emits them).
"""

import os
import sys
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _candidate in (os.path.join(_REPO_ROOT, "app"), _REPO_ROOT):
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

import constants  # noqa: E402


class TestConstants(unittest.TestCase):
    def test_completion_marker_matches_tcl_contract(self):
        # cable.tcl emits: SafeLog "Script done!"
        self.assertEqual(constants.SCRIPT_DONE_MARKER, "Script done!")

    def test_execution_time_prefix(self):
        self.assertEqual(constants.EXECUTION_TIME_PREFIX, "EXECUTION_TIME:")

    def test_orcad_window_class(self):
        self.assertEqual(constants.ORCAD_WINDOW_CLASS, "OrCaptureFrame")

    def test_english_layout_id(self):
        self.assertEqual(constants.ENGLISH_LAYOUT_ID, 0x0409)


if __name__ == "__main__":
    unittest.main(verbosity=2)
