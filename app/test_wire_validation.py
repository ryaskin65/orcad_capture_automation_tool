"""Unit tests for WireDataProcessor validation rules.

These tests cover pure validation logic and have no dependency on tkinter,
openpyxl or OrCAD, so they run in any environment with `pytest` (or the
stdlib `unittest` runner).

Run from the repository root:
    pytest tests/test_wire_validation.py
or:
    python -m unittest tests.test_wire_validation
"""

import os
import sys
import unittest

# Make the `app/` package importable when running from the repo root.
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _candidate in (os.path.join(_REPO_ROOT, "app"), _REPO_ROOT):
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

from wire_data import WireData, WireDataProcessor  # noqa: E402


class _FakeLogger:
    """Minimal stand-in for MessageLogger used in tests."""

    def __init__(self):
        self.messages = []

    def log_message(self, level, message, update_last=False):
        self.messages.append((level, message))


def make_wire(signal, left, right, wire_type="", connect_left="", connect_right=""):
    """Helper to build a WireData with sensible defaults for tests."""
    return WireData(
        signal_name=signal,
        left_connector=left,
        right_connector=right,
        left_in_out="IN",
        wire_type=wire_type,
        left_gauge="20",
        color="WHITE",
        right_gauge="20",
        connect_left=connect_left,
        connect_right=connect_right,
    )


class TestWireTypeRules(unittest.TestCase):
    def setUp(self):
        self.proc = WireDataProcessor(_FakeLogger())

    def test_valid_twisted_pair_has_no_errors(self):
        wires = [
            make_wire("S1", "C1/A1", "C2/A1", wire_type="TW"),
            make_wire("S2", "C1/A2", "C2/A2", wire_type="TW"),
        ]
        errors, _ = self.proc.validate_wire_type_rules("P1", wires)
        self.assertEqual(errors, [])

    def test_lone_twisted_wire_reports_error(self):
        wires = [
            make_wire("S1", "C1/A1", "C2/A1", wire_type="TW"),
            make_wire("S2", "C1/A2", "C2/A2", wire_type=""),
        ]
        errors, _ = self.proc.validate_wire_type_rules("P1", wires)
        self.assertTrue(errors, "Expected an error for an unpaired twisted wire")

    def test_trailing_twisted_wire_reports_error(self):
        wires = [make_wire("S1", "C1/A1", "C2/A1", wire_type="ST")]
        errors, _ = self.proc.validate_wire_type_rules("P1", wires)
        self.assertTrue(errors, "Single trailing twisted wire must be flagged")


class TestConnectorPins(unittest.TestCase):
    def setUp(self):
        self.proc = WireDataProcessor(_FakeLogger())

    def test_duplicate_pin_same_connector_is_error(self):
        wires = [
            make_wire("S1", "L1/A1", "R1/B1"),
            make_wire("S2", "L1/A1", "R1/B2"),  # duplicate left pin L1/A1
        ]
        errors, _ = self.proc.validate_connector_pins("P1", wires)
        self.assertTrue(any("Duplicate pin" in e for e in errors))

    def test_same_pin_on_left_and_right_is_allowed(self):
        wires = [make_wire("S1", "X/A1", "X/A1")]
        errors, _ = self.proc.validate_connector_pins("P1", wires)
        self.assertEqual(errors, [])

    def test_missing_slash_is_format_error(self):
        wires = [make_wire("S1", "BADPIN", "R1/B1")]
        errors, _ = self.proc.validate_connector_pins("P1", wires)
        self.assertTrue(any("CONNECTOR_NAME/PIN_NAME" in e for e in errors))


class TestSignalNames(unittest.TestCase):
    def setUp(self):
        self.proc = WireDataProcessor(_FakeLogger())

    def test_duplicate_signal_name_is_error(self):
        wires = [
            make_wire("DUP", "C1/A1", "C2/A1"),
            make_wire("DUP", "C1/A2", "C2/A2"),
        ]
        errors, _ = self.proc.validate_signal_names("P1", wires)
        self.assertTrue(any("Duplicate signal name" in e for e in errors))

    def test_repeated_space_marker_is_allowed(self):
        wires = [
            make_wire("SPACE", "", ""),
            make_wire("SPACE", "", ""),
        ]
        errors, _ = self.proc.validate_signal_names("P1", wires)
        self.assertEqual(errors, [])


class TestConnectionConsistency(unittest.TestCase):
    def setUp(self):
        self.proc = WireDataProcessor(_FakeLogger())

    def test_chain_longer_than_two_is_error(self):
        # 1 -> 2 -> 3 on the left side: chain length 3, must be rejected
        wires = [
            make_wire("S1", "C1/A1", "C2/A1", connect_left="2"),
            make_wire("S2", "C1/A2", "C2/A2", connect_left="3"),
            make_wire("S3", "C1/A3", "C2/A3"),
        ]
        errors, _ = self.proc.validate_connection_consistency("P1", wires)
        self.assertTrue(errors, "A 3-wire connection chain must produce an error")

    def test_simple_pair_connection_is_not_error(self):
        # 1 -> 2 only: allowed (produces a warning, not an error)
        wires = [
            make_wire("S1", "C1/A1", "C2/A1", connect_left="2"),
            make_wire("S2", "C1/A2", "C2/A2"),
        ]
        errors, _ = self.proc.validate_connection_consistency("P1", wires)
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
