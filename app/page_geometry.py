# RIGa&AI 2026 - page capacity calculation
"""Page geometry / capacity calculator.

Mirrors the vertical layout arithmetic of the TCL drawing script
(``scripts/cable.tcl``) so that a page which would overflow the sheet is
rejected *before* the script runs, instead of OrCAD silently skipping the
out-of-bounds connector rectangle (which leaves a broken schematic).

Units note
----------
cable.tcl checks the *page size* in millimetres (CheckPageA3Millimeters:
420 x 297 mm). The drawing *coordinates*, however, are computed in OrCAD
drawing units (grid step ``STEP_XY = 2.54``) and bounds-checked against
``A3_WIDTH = 414`` and ``A3_HEIGHT = 350``. Per the project owner the vertical
bound ``350`` is in OrCAD display units (pixels), NOT millimetres, so it must
not be compared against the 297 mm physical page height directly.

This class deliberately works in the *same* coordinate space and against the
*same* bound (``A3_HEIGHT``) that cable.tcl uses, so its verdict matches the
script exactly. All quantities below are in OrCAD drawing units, not mm.

Vertical layout (cable.tcl line 907):
    Y = StartWireY + (numLines + numSpaceLines) * StepWireY

Lowest drawn element is the connector rectangle (cable.tcl lines 1029-1030):
    Y_bottom = (StartWireY - 4*STEP_XY) + (maxRow + 3) * StepWireY
             = STEP_XY * (2 * maxRow + 10)

PlaceRectangleCheck rejects it when ``Y_bottom > A3_HEIGHT``; that is the bound
enforced here. ``maxRow`` is the largest 1-based row index that OffsetCalculator
produces for the page.
"""

from typing import Dict, List, Any, Tuple


class PageGeometry:
    # --- constants mirrored from cable.tcl (OrCAD drawing units) ----------
    STEP_XY = 2.54          # grid step (cable.tcl: set STEP_XY 2.54)
    A3_WIDTH = 414.0        # horizontal bound used by cable.tcl
    A3_HEIGHT = 350.0       # vertical bound used by cable.tcl (display units)

    def __init__(self, step_xy: float = None, start_wire_steps: int = 8,
                 wire_pitch_steps: int = 2, bottom_structure_steps: int = 3,
                 top_offset_steps: int = 4, max_y: float = None):
        """
        Args mirror the cable.tcl layout parameters (all in drawing units):
            step_xy             : grid step (default 2.54)
            start_wire_steps    : top margin to the first wire row, in steps
                                  (cable.tcl: StartWireY = 8 * STEP_XY)
            wire_pitch_steps    : vertical pitch between rows, in steps
                                  (cable.tcl: StepWireY = 2 * STEP_XY)
            bottom_structure_steps : extra rows the connector rectangle adds
                                  below the last wire (cable.tcl: +3 in L)
            top_offset_steps    : how far above StartWireY the rectangle starts
                                  (cable.tcl: StartWireY - 4 * STEP_XY)
            max_y               : vertical bound to enforce (default A3_HEIGHT)
        """
        self.step_xy = step_xy if step_xy is not None else self.STEP_XY
        self.start_wire = start_wire_steps * self.step_xy
        self.wire_pitch = wire_pitch_steps * self.step_xy
        self.bottom_structure_steps = bottom_structure_steps
        self.top_offset = top_offset_steps * self.step_xy
        self.max_y = max_y if max_y is not None else self.A3_HEIGHT

    def row_to_y(self, relative_y: int) -> float:
        """Y coordinate (drawing units) of a wire at the given 1-based row."""
        return self.start_wire + (relative_y - 1) * self.wire_pitch

    def lowest_element_y(self, max_relative_y: int) -> float:
        """Bottom edge of the connector rectangle (the lowest drawn element)."""
        rect_top = self.start_wire - self.top_offset
        length = (max_relative_y + self.bottom_structure_steps) * self.wire_pitch
        return rect_top + length

    def max_usable_rows(self) -> int:
        """Largest ``max_relative_y`` whose layout still fits the sheet."""
        rect_top = self.start_wire - self.top_offset
        usable = self.max_y - rect_top
        rows = int(usable / self.wire_pitch) - self.bottom_structure_steps
        return max(rows, 0)

    def validate_page(
        self, wire_data_array: List[Dict[str, Any]]
    ) -> Tuple[bool, str, Dict[str, Any]]:
        """Validate that a page's wire layout fits within the sheet.

        Args:
            wire_data_array: per-wire dicts from OffsetCalculator (need 'y').

        Returns:
            (ok, message, info) where info has 'max_row', 'rows_available',
            'lowest_y' and 'max_y' for diagnostics (all in drawing units).
        """
        rows_available = self.max_usable_rows()
        if not wire_data_array:
            return True, "", {"max_row": 0, "rows_available": rows_available,
                              "lowest_y": 0.0, "max_y": self.max_y}

        max_row = max(int(d.get("y", 0)) for d in wire_data_array)
        lowest_y = self.lowest_element_y(max_row)
        info = {
            "max_row": max_row,
            "rows_available": rows_available,
            "lowest_y": round(lowest_y, 2),
            "max_y": self.max_y,
        }

        if lowest_y > self.max_y:
            msg = (
                f"too many wires/spacing for one page: layout needs {max_row} "
                f"rows, but the sheet allows {rows_available}. "
                f"Split the wires across more pages or reduce spacing."
            )
            return False, msg, info

        return True, "", info
