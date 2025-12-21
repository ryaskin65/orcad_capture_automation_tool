# RIGa&DeepSeek 21.12.2025

# orcad_canvas.py
from dataclasses import dataclass
from typing import Dict, Tuple, Set, List, Optional


@dataclass
class CanvasPoint:
    """Point on canvas with integer grid coordinates"""

    x: int  # Horizontal position in grid steps (2.54 mm each)
    y: int  # Vertical position in grid steps (2.54 mm each)


class OrcadCanvas:
    """
    Simplified model of Orcad Capture canvas for wire placement validation.

    Features:
    - Integer grid coordinates (2.54 mm per step)
    - A3 page dimensions in grid steps
    - Validation of wire placement boundaries
    - Coordinate conversion between relative and canvas coordinates

    Note: This is used only for boundary validation, not for offset calculations.
    Offset calculations are handled by OffsetCalculator class.
    """

    # Canvas A3 dimensions in grid steps (2.54 mm per step)
    A3_WIDTH_STEPS = 165  # 420mm / 2.54 ≈ 165 steps
    A3_HEIGHT_STEPS = 117  # 297mm / 2.54 ≈ 117 steps
    GRID_STEP = 2.54  # mm per grid step

    # Wire drawing areas (left and right from center)
    # These define where wires can be placed horizontally
    LEFT_AREA_WIDTH = 40  # Number of grid steps left from center
    RIGHT_AREA_WIDTH = 40  # Number of grid steps right from center
    CENTER_X = A3_WIDTH_STEPS // 2  # Center of canvas

    # Vertical boundaries for wire placement
    # Wires cannot be placed too close to top or bottom edges
    TOP_MARGIN = 8  # 8 grid steps from top (≈20mm)
    BOTTOM_MARGIN = 8  # 8 grid steps from bottom (≈20mm)
    MIN_Y = TOP_MARGIN  # Minimum valid Y coordinate
    MAX_Y = A3_HEIGHT_STEPS - BOTTOM_MARGIN  # Maximum valid Y coordinate

    def __init__(self):
        """Initialize canvas with empty wire positions"""
        self.wire_positions = {}  # wire_num -> (left_y, right_y) in canvas coordinates
        self.occupied_positions = set()  # Set of (x, y) points already occupied

    def validate_wire_placement(
        self, wire_num: int, left_y: int, right_y: int
    ) -> Tuple[bool, str]:
        """
        Validate if wire can be placed at specified coordinates

        Checks:
        1. Y coordinates are within canvas vertical boundaries
        2. Wire positions are not already occupied
        3. Coordinates are positive integers

        Args:
            wire_num: Wire number (1-based)
            left_y: Y coordinate for left side of wire (canvas coordinates)
            right_y: Y coordinate for right side of wire (canvas coordinates)

        Returns:
            Tuple (success, error_message)
            - success: True if wire can be placed, False otherwise
            - error_message: Description of validation failure if any
        """
        # Check vertical boundaries
        if left_y < self.MIN_Y or left_y > self.MAX_Y:
            return (
                False,
                f"Left Y={left_y} outside canvas bounds [{self.MIN_Y}, {self.MAX_Y}]",
            )

        if right_y < self.MIN_Y or right_y > self.MAX_Y:
            return (
                False,
                f"Right Y={right_y} outside canvas bounds [{self.MIN_Y}, {self.MAX_Y}]",
            )

        # Calculate absolute positions on canvas
        left_x = self.CENTER_X - self.LEFT_AREA_WIDTH
        right_x = self.CENTER_X + self.RIGHT_AREA_WIDTH

        left_pos = (left_x, left_y)
        right_pos = (right_x, right_y)

        # Check if positions are already occupied
        if left_pos in self.occupied_positions:
            return False, f"Left position {left_pos} already occupied"

        if right_pos in self.occupied_positions:
            return False, f"Right position {right_pos} already occupied"

        return True, ""

    def place_wire(self, wire_num: int, left_y: int, right_y: int) -> bool:
        """
        Place a wire on the canvas at specified coordinates

        Note: Coordinates should be in canvas coordinate system
        (not relative coordinates from OffsetCalculator)

        Args:
            wire_num: Wire number (1-based)
            left_y: Y coordinate for left side (canvas coordinates)
            right_y: Y coordinate for right side (canvas coordinates)

        Returns:
            True if wire was placed successfully, False otherwise
        """
        # Validate placement first
        success, error = self.validate_wire_placement(wire_num, left_y, right_y)
        if not success:
            return False

        # Calculate absolute positions
        left_x = self.CENTER_X - self.LEFT_AREA_WIDTH
        right_x = self.CENTER_X + self.RIGHT_AREA_WIDTH

        left_pos = (left_x, left_y)
        right_pos = (right_x, right_y)

        # Mark positions as occupied
        self.occupied_positions.add(left_pos)
        self.occupied_positions.add(right_pos)

        # Store wire position
        self.wire_positions[wire_num] = (left_y, right_y)

        return True

    def place_wire_relative(
        self, wire_num: int, relative_left_y: int, relative_right_y: int
    ) -> bool:
        """
        Place wire using relative Y coordinates (starting from 1)

        Converts relative coordinates to canvas coordinates:
        canvas_y = relative_y + MIN_Y - 1

        Args:
            wire_num: Wire number (1-based)
            relative_left_y: Relative Y coordinate for left side (1-based)
            relative_right_y: Relative Y coordinate for right side (1-based)

        Returns:
            True if wire was placed successfully, False otherwise
        """
        # Convert relative coordinates to canvas coordinates
        canvas_left_y = relative_left_y + self.MIN_Y - 1
        canvas_right_y = relative_right_y + self.MIN_Y - 1

        return self.place_wire(wire_num, canvas_left_y, canvas_right_y)

    def get_wire_y(self, wire_num: int, side: str) -> int:
        """
        Get Y-coordinate of wire on specified side

        Args:
            wire_num: Wire number (1-based)
            side: 'left' or 'right'

        Returns:
            Y coordinate in canvas coordinate system
            If wire not placed, returns default position based on wire number
        """
        if wire_num in self.wire_positions:
            left_y, right_y = self.wire_positions[wire_num]
            return left_y if side == "left" else right_y
        else:
            # Return default position if wire not placed
            return wire_num + self.MIN_Y - 1

    def get_wire_relative_y(self, wire_num: int, side: str) -> int:
        """
        Get relative Y-coordinate (starting from 1)

        Converts canvas coordinates to relative coordinates:
        relative_y = canvas_y - MIN_Y + 1

        Args:
            wire_num: Wire number (1-based)
            side: 'left' or 'right'

        Returns:
            Relative Y coordinate (1-based)
        """
        canvas_y = self.get_wire_y(wire_num, side)
        return canvas_y - self.MIN_Y + 1

    def calculate_offset(
        self, source_wire_num: int, target_wire_num: int, side: str
    ) -> int:
        """
        Calculate vertical offset between two wires

        Formula: offset = target_y - source_y
        Uses relative coordinates (1-based)

        Args:
            source_wire_num: Source wire number
            target_wire_num: Target wire number
            side: 'left' or 'right'

        Returns:
            Vertical offset in grid steps
        """
        source_y = self.get_wire_relative_y(source_wire_num, side)
        target_y = self.get_wire_relative_y(target_wire_num, side)

        return target_y - source_y

    def reset(self):
        """
        Reset canvas to empty state

        Clears all wire positions and occupied points
        """
        self.wire_positions.clear()
        self.occupied_positions.clear()

    def check_canvas_bounds(self, relative_y: int) -> Tuple[bool, str]:
        """
        Check if relative Y coordinate fits within canvas bounds

        Args:
            relative_y: Relative Y coordinate (1-based)

        Returns:
            Tuple (is_valid, error_message)
        """
        canvas_y = relative_y + self.MIN_Y - 1

        if canvas_y < self.MIN_Y or canvas_y > self.MAX_Y:
            return (
                False,
                f"Y={canvas_y} outside canvas bounds [{self.MIN_Y}, {self.MAX_Y}]",
            )

        return True, ""

    def get_canvas_y_from_relative(self, relative_y: int) -> int:
        """
        Convert relative Y coordinate to canvas Y coordinate

        Args:
            relative_y: Relative Y coordinate (1-based)

        Returns:
            Canvas Y coordinate
        """
        return relative_y + self.MIN_Y - 1

    def get_relative_y_from_canvas(self, canvas_y: int) -> int:
        """
        Convert canvas Y coordinate to relative Y coordinate

        Args:
            canvas_y: Canvas Y coordinate

        Returns:
            Relative Y coordinate (1-based)
        """
        return canvas_y - self.MIN_Y + 1

    def get_wire_count(self) -> int:
        """Get number of wires placed on canvas"""
        return len(self.wire_positions)

    def is_position_occupied(self, x: int, y: int) -> bool:
        """
        Check if a specific canvas position is occupied

        Args:
            x: X coordinate in canvas system
            y: Y coordinate in canvas system

        Returns:
            True if position is occupied, False otherwise
        """
        return (x, y) in self.occupied_positions
