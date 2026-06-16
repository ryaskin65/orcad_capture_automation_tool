"""Tests for the pure page-row selection logic (no GUI deps)."""

import os
import sys
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _candidate in (os.path.join(_REPO_ROOT, "app"), _REPO_ROOT):
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

from cable_page import select_page_rows  # noqa: E402


def sample():
    return [
        ["ProjectNumber", "31-667"],
        ["NameLeftSide", "SIM"],
        ["", ""],
        ["PAGE", "PAGE1"],
        ["Sig1", "L/A1", "R/B1"],
        ["Sig2", "L/A2", "R/B2"],
        ["", ""],
        ["PAGE", "PAGE2"],
        ["Sig3", "L/A3", "R/B3"],
    ]


class TestSelectPageRows(unittest.TestCase):
    def test_selects_target_page_with_header(self):
        data = select_page_rows(sample(), "PAGE1")
        self.assertIn(["ProjectNumber", "31-667"], data)
        self.assertIn(["PAGE", "PAGE1"], data)
        self.assertIn(["Sig1", "L/A1", "R/B1"], data)
        # PAGE2 rows must not leak in
        self.assertNotIn(["Sig3", "L/A3", "R/B3"], data)
        self.assertNotIn(["PAGE", "PAGE2"], data)

    def test_selects_last_page(self):
        data = select_page_rows(sample(), "PAGE2")
        self.assertIn(["PAGE", "PAGE2"], data)
        self.assertIn(["Sig3", "L/A3", "R/B3"], data)
        self.assertNotIn(["Sig1", "L/A1", "R/B1"], data)

    def test_unknown_page_returns_header_only(self):
        data = select_page_rows(sample(), "NOPE")
        # Header is still returned; no page rows.
        self.assertIn(["ProjectNumber", "31-667"], data)
        self.assertFalse(any(r and r[0] == "PAGE" for r in data))

    def test_duplicate_header_directive_keeps_last_value(self):
        rows = [
            ["ProjectNumber", "OLD"],
            ["ProjectNumber", "NEW"],
            ["PAGE", "P1"],
            ["Sig1", "a", "b"],
        ]
        data = select_page_rows(rows, "P1")
        proj = [r for r in data if r[0] == "ProjectNumber"]
        self.assertEqual(len(proj), 1)
        self.assertEqual(proj[0][1], "NEW")

    def test_empty_input(self):
        self.assertEqual(select_page_rows([], "P1"), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
