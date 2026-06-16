"""Tests for the PageGeometry capacity calculator (pure, no GUI deps)."""

import os
import sys
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _candidate in (os.path.join(_REPO_ROOT, "app"), _REPO_ROOT):
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

from page_geometry import PageGeometry  # noqa: E402


def rows(*ys):
    """Build a minimal wire_data_array with the given 1-based row indices."""
    return [{"y": y, "left_x_offset": "", "right_x_offset": ""} for y in ys]


class TestPageGeometry(unittest.TestCase):
    def setUp(self):
        self.geom = PageGeometry()

    def test_row_to_y_matches_tcl_formula(self):
        # StartWireY = 8 * 2.54 = 20.32 mm; first row sits exactly there.
        self.assertAlmostEqual(self.geom.row_to_y(1), 8 * 2.54, places=6)
        # Each extra row adds StepWireY = 2 * 2.54.
        self.assertAlmostEqual(
            self.geom.row_to_y(2), 8 * 2.54 + 2 * 2.54, places=6
        )

    def test_lowest_element_formula(self):
        # Y_bottom = STEP_XY * (2 * maxY + 10)
        for max_y in (1, 10, 50):
            self.assertAlmostEqual(
                self.geom.lowest_element_y(max_y),
                2.54 * (2 * max_y + 10),
                places=6,
            )

    def test_capacity_budget_is_63_rows(self):
        # Derived from STEP_XY*(2*maxY+10) <= 350  ->  maxY <= 63
        self.assertEqual(self.geom.max_usable_rows(), 63)

    def test_layout_within_bounds_passes(self):
        ok, msg, info = self.geom.validate_page(rows(1, 20, 63))
        self.assertTrue(ok, msg)
        self.assertEqual(info["max_row"], 63)

    def test_layout_exceeding_bounds_fails(self):
        ok, msg, info = self.geom.validate_page(rows(1, 30, 64))
        self.assertFalse(ok)
        self.assertIn("too many wires", msg)
        self.assertEqual(info["max_row"], 64)
        self.assertGreater(info["lowest_y"], info["max_y"])

    def test_empty_page_is_ok(self):
        ok, _msg, info = self.geom.validate_page([])
        self.assertTrue(ok)
        self.assertEqual(info["max_row"], 0)

    def test_smaller_bound_reduces_capacity(self):
        # The vertical bound is configurable (drawing units, not mm).
        smaller = PageGeometry(max_y=300)
        self.assertLess(smaller.max_usable_rows(), self.geom.max_usable_rows())


if __name__ == "__main__":
    unittest.main(verbosity=2)
