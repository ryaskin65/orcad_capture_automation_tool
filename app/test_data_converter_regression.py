"""Regression test for the duplicate-message fix in DataConverter.

Before the fix, `_validate_data_structure` called `validate_splice_rules`
twice, so every splice-related message was reported twice. This test asserts
that a splice warning is produced exactly once.

This test imports `data_converter`, which transitively requires `openpyxl`
and `tkinter`. On environments without those (e.g. a headless CI box) the
test is skipped automatically. It runs normally on the development machine.

Run from the repository root:
    pytest tests/test_data_converter_regression.py
"""

import os
import sys
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _candidate in (os.path.join(_REPO_ROOT, "app"), _REPO_ROOT):
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

try:
    from data_converter import DataConverter
    from wire_data import WireData
    _IMPORT_ERROR = None
except Exception as exc:  # pragma: no cover - environment dependent
    DataConverter = None
    WireData = None
    _IMPORT_ERROR = exc


class _FakeLogger:
    def __init__(self):
        self.messages = []

    def log_message(self, level, message, update_last=False):
        self.messages.append((level, message))


def _make_wire(signal, left, right, connect_left=""):
    return WireData(
        signal_name=signal,
        left_connector=left,
        right_connector=right,
        left_in_out="IN",
        wire_type="",
        left_gauge="20",
        color="WHITE",
        right_gauge="20",
        connect_left=connect_left,
        connect_right="",
    )


@unittest.skipIf(DataConverter is None, f"deps unavailable: {_IMPORT_ERROR}")
class TestNoDuplicateSpliceMessages(unittest.TestCase):
    def test_splice_warning_is_not_duplicated(self):
        converter = DataConverter(_FakeLogger())

        # Wire 1 is both a source (-> 2) and a target (<- 2): triggers the
        # "both target and source of left connections" warning from
        # validate_splice_rules. Before the fix it was emitted twice.
        wires = [
            _make_wire("S1", "C1/A1", "C2/A1", connect_left="2"),
            _make_wire("S2", "C1/A2", "C2/A2", connect_left="1"),
        ]
        data = {
            "headers": {},
            "pages": {
                "P1": {
                    "wire_headers": [
                        "Signal name",
                        "Right connector",
                        "Left connector",
                    ],
                    "wires": wires,
                }
            },
        }

        _is_valid, _errors, warnings = converter._validate_data_structure(data)

        both_msgs = [w for w in warnings if "both target and source" in w]
        # Exactly one warning per affected wire, not two.
        self.assertTrue(both_msgs, "Expected the splice warning to be produced")
        for msg in set(both_msgs):
            self.assertEqual(
                both_msgs.count(msg),
                1,
                f"Splice warning was duplicated: {msg!r}",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
