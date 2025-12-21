# RIGa&DeepSeek 21.12.2025

from typing import Dict, List, Tuple, Set, Optional, Any
import re
from wire_data import WireData


class OffsetCalculator:
    """Calculator for wire offsets and groups according to TCL rules"""

    def __init__(self, message_logger):
        self.message_logger = message_logger

    def calculate_wire_data(self, wires: List[WireData]) -> List[Dict[str, Any]]:
        """
        Main method to calculate all wire data including coordinates and offsets

        Returns: List of dicts where index = wire_num-1, each dict contains:
        {
            'y': int,              # Y coordinate (1-based)
            'left_x_offset': str,  # Left group (0, 1, 2 or ""), represents X offset
            'left_y_offset': str,  # Left vertical offset (Y direction)
            'right_x_offset': str, # Right group (0, 1, 2 or "")
            'right_y_offset': str, # Right vertical offset (Y direction)
            'is_splice': bool,     # Is this wire a splice (target of connections)?
            'has_left_connection': bool,  # Has outgoing left connection
            'has_right_connection': bool, # Has outgoing right connection
            'left_target': Optional[int], # Target wire for left connection
            'right_target': Optional[int] # Target wire for right connection
        }
        """
        # 1. Calculate Y coordinates according to TCL rules
        y_coordinates = self._calculate_y_coordinates(wires)

        # 2. Parse all connections from input data
        connections = self._parse_connections(wires)

        # 3. Calculate X offsets (groups) for left and right sides
        # Groups prevent short circuits between wires with overlapping Y ranges
        groups = self._calculate_groups(connections, len(wires), y_coordinates)

        # 4. Build result array with all calculated data
        result = []
        for i, wire in enumerate(wires):
            wire_num = i + 1
            wire_data = self._process_single_wire(
                wire, wire_num, y_coordinates, connections, groups
            )
            result.append(wire_data)

        return result

    def _calculate_y_coordinates(self, wires: List[WireData]) -> Dict[int, int]:
        """
        Calculate Y coordinates according to TCL spacing rules

        Rules:
        - Each wire: +1 to num_lines
        - Connector change on either side: +3 to num_space_lines
        - Only group change (same connector): +2 to num_space_lines
        - After twisted pair: +1 to num_space_lines (if not last in group/connector)

        Returns: {wire_num: y_coordinate} where coordinates are 1-based
        """
        coordinates = {}
        num_lines = 0  # Counter for basic wire lines
        num_space_lines = 0  # Counter for extra spacing lines

        # Track previous values for change detection
        prev_left_connector = ""
        prev_right_connector = ""
        prev_left_group = ""
        prev_right_group = ""
        prev_type_pair = 0  # 0 = not twisted, 1 = twisted

        # We need to know groups/connectors in advance for the "not last in group" check
        # Pre-calculate groups for all wires
        all_groups = []
        all_connectors = []

        for i, wire in enumerate(wires):
            # Get connector names (without pin)
            left_connector = self._get_connector_name(wire.left_connector)
            right_connector = self._get_connector_name(wire.right_connector)

            # Get group names using TCL GetGroupName logic
            left_group = self._get_group_name(wire.left_connector, wires, "left")
            right_group = self._get_group_name(wire.right_connector, wires, "right")

            all_groups.append((left_group, right_group))
            all_connectors.append((left_connector, right_connector))

        # Main calculation loop
        for i, wire in enumerate(wires):
            wire_num = i + 1

            left_connector = all_connectors[i][0]
            right_connector = all_connectors[i][1]
            left_group = all_groups[i][0]
            right_group = all_groups[i][1]

            # Check for changes (fLC, fRC, fLS, fRS from TCL code)
            fLC = bool(left_connector and left_connector != prev_left_connector)
            fRC = bool(right_connector and right_connector != prev_right_connector)
            fLS = bool(left_group and left_group != prev_left_group)
            fRS = bool(right_group and right_group != prev_right_group)

            # Check if this is a twisted pair wire
            wire_type = wire.wire_type.upper() if wire.wire_type else ""
            type_pair = (
                1 if wire_type in ["TWISTED", "TW", "SHIELDED TWISTED", "ST"] else 0
            )

            # Reset twisted pair tracking if connector changed
            if fRC or fLC:
                prev_type_pair = 0

            # Apply spacing rules based on changes
            if wire_num > 1 and (fLS or fRS or fLC or fRC):
                if fLC or fRC:
                    # Connector changed: add 3 spacing lines
                    num_space_lines += 3
                else:
                    # Only group changed (same connector): add 2 spacing lines
                    num_space_lines += 2
            elif type_pair == 0 and prev_type_pair == 1:
                # After twisted pair: add 1 spacing line IF not last in group/connector
                # Check if the previous wire (which was twisted) was NOT the last in its group/connector
                prev_wire_idx = i - 1  # index of previous wire (the twisted one)

                if prev_wire_idx >= 0:
                    # Get groups/connectors for previous wire
                    prev_left_group_wire = all_groups[prev_wire_idx][0]
                    prev_right_group_wire = all_groups[prev_wire_idx][1]
                    prev_left_connector_wire = all_connectors[prev_wire_idx][0]
                    prev_right_connector_wire = all_connectors[prev_wire_idx][1]

                    # Check if there's another wire after this with same group/connector
                    is_last_in_group = True
                    for next_idx in range(i, len(wires)):
                        next_left_group = all_groups[next_idx][0]
                        next_right_group = all_groups[next_idx][1]
                        next_left_connector = all_connectors[next_idx][0]
                        next_right_connector = all_connectors[next_idx][1]

                        # Check if any following wire has same group or connector on either side
                        if (
                            (
                                next_left_group == prev_left_group_wire
                                and prev_left_group_wire
                            )
                            or (
                                next_right_group == prev_right_group_wire
                                and prev_right_group_wire
                            )
                            or (
                                next_left_connector == prev_left_connector_wire
                                and prev_left_connector_wire
                            )
                            or (
                                next_right_connector == prev_right_connector_wire
                                and prev_right_connector_wire
                            )
                        ):
                            is_last_in_group = False
                            break

                    # Add +1 only if NOT last in group/connector
                    if not is_last_in_group:
                        num_space_lines += 1

            # Calculate Y coordinate: lines + spacing + 1 (1-based)
            y_coord = num_lines + num_space_lines + 1
            coordinates[wire_num] = y_coord

            # Update tracking variables for next iteration
            num_lines += 1
            prev_type_pair = type_pair
            if left_group:
                prev_left_group = left_group
            if right_group:
                prev_right_group = right_group
            if left_connector:
                prev_left_connector = left_connector
            if right_connector:
                prev_right_connector = right_connector

        return coordinates

    def _parse_connections(self, wires: List[WireData]) -> Dict[str, Any]:
        """
        Parse all connection data from wire data

        Splice wires are ONLY wires that are targets of connections
        Returns: Dictionary containing:
        {
            'left_connections': {source_wire: target_wire},
            'right_connections': {source_wire: target_wire},
            'splice_wires': Set[int],  # Wires that are targets (splices)
            'all_connections': List[Tuple[source, target, side]]
        }
        """
        left_connections = {}
        right_connections = {}
        splice_wires = set()  # ONLY wires that are TARGETS
        all_connections = []

        for i, wire in enumerate(wires):
            wire_num = i + 1

            # Parse left connections (Connect to left wire with number)
            if wire.connect_left and wire.connect_left.strip():
                try:
                    target = int(wire.connect_left.strip())
                    if 1 <= target <= len(wires):
                        left_connections[wire_num] = target
                        # ONLY target wire is a splice
                        splice_wires.add(target)
                        all_connections.append((wire_num, target, "left"))
                except ValueError:
                    pass

            # Parse right connections (Connect to right wire with number)
            if wire.connect_right and wire.connect_right.strip():
                try:
                    target = int(wire.connect_right.strip())
                    if 1 <= target <= len(wires):
                        right_connections[wire_num] = target
                        # ONLY target wire is a splice
                        splice_wires.add(target)
                        all_connections.append((wire_num, target, "right"))
                except ValueError:
                    pass

        return {
            "left_connections": left_connections,
            "right_connections": right_connections,
            "splice_wires": splice_wires,
            "all_connections": all_connections,
        }

    def _calculate_groups(
        self,
        connections: Dict[str, Any],
        total_wires: int,
        y_coordinates: Dict[int, int],
    ) -> Dict[int, Dict[str, str]]:
        """
        Calculate X offsets (groups) with maximum 2 groups (0,1) per side

        FIXED LOGIC: Groups are assigned ONLY to:
        1. Splice wires (target wires)
        2. Wires that connect to splice wires
        3. Wires without connections DO NOT get groups

        Returns: {wire_num: {"left": group_str, "right": group_str}}
                 where group_str is "0", "1", "2" or "" (empty for no group)
        """
        # Build connection map: target_wire -> [(source, side), ...]
        connection_map = {}
        for source, target, side in connections["all_connections"]:
            if target not in connection_map:
                connection_map[target] = []
            connection_map[target].append((source, side))

        # Group splices by side
        left_splices = {}  # splice_wire -> [source_wires]
        right_splices = {}  # splice_wire -> [source_wires]

        for target, sources in connection_map.items():
            left_sources = [s for s, side in sources if side == "left"]
            right_sources = [s for s, side in sources if side == "right"]

            if left_sources:
                left_splices[target] = left_sources
            if right_sources:
                right_splices[target] = right_sources

        # Initialize all groups as empty (no group assigned)
        # We use None to indicate "no group needed"
        tentative_groups = {}
        for wire_num in range(1, total_wires + 1):
            tentative_groups[wire_num] = {"left": None, "right": None}

        # Helper function to get Y-range for a physical group
        def get_y_range(wires_list, include_splice=False, splice_wire=None):
            """Get min and max Y for a list of wires, optionally including splice"""
            if not wires_list:
                return None, None

            y_values = [y_coordinates.get(w, w) for w in wires_list]
            if include_splice and splice_wire:
                y_values.append(y_coordinates.get(splice_wire, splice_wire))

            return min(y_values), max(y_values)

        # Process left side splices
        left_splice_groups = {}  # splice -> assigned X-group (0, 1, or 2)

        for splice, sources in left_splices.items():
            # Get Y-range for this physical group (splice + its sources)
            min_y, max_y = get_y_range(sources, include_splice=True, splice_wire=splice)

            # Try to find compatible X-group (0, 1, or 2)
            compatible_groups = {0, 1, 2}

            for other_splice, other_group in left_splice_groups.items():
                other_sources = left_splices[other_splice]
                other_min, other_max = get_y_range(
                    other_sources, include_splice=True, splice_wire=other_splice
                )

                # Check if Y-ranges intersect
                ranges_intersect = (
                    (min_y < other_min < max_y)
                    or (min_y < other_max < max_y)
                    or (other_min < min_y < other_max)
                    or (other_min < max_y < other_max)
                )

                if ranges_intersect:
                    # Ranges intersect - cannot share same group
                    if other_group in compatible_groups:
                        compatible_groups.remove(other_group)

            # Assign group (prefer 0, then 1, then 2)
            if 0 in compatible_groups:
                assigned_group = 0
            elif 1 in compatible_groups:
                assigned_group = 1
            elif 2 in compatible_groups:
                assigned_group = 2
            else:
                # No compatible group found - error condition
                # This means we need more than 3 X-groups
                assigned_group = 0  # Fallback, will cause validation error later

            left_splice_groups[splice] = assigned_group

        # Process right side splices (same logic)
        right_splice_groups = {}

        for splice, sources in right_splices.items():
            min_y, max_y = get_y_range(sources, include_splice=True, splice_wire=splice)

            compatible_groups = {0, 1, 2}

            for other_splice, other_group in right_splice_groups.items():
                other_sources = right_splices[other_splice]
                other_min, other_max = get_y_range(
                    other_sources, include_splice=True, splice_wire=other_splice
                )

                ranges_intersect = (
                    (min_y < other_min < max_y)
                    or (min_y < other_max < max_y)
                    or (other_min < min_y < other_max)
                    or (other_min < max_y < other_max)
                )

                if ranges_intersect:
                    if other_group in compatible_groups:
                        compatible_groups.remove(other_group)

            if 0 in compatible_groups:
                assigned_group = 0
            elif 1 in compatible_groups:
                assigned_group = 1
            elif 2 in compatible_groups:
                assigned_group = 2
            else:
                assigned_group = 0  # Fallback

            right_splice_groups[splice] = assigned_group

        # NEW: Determine which wires actually need groups
        # Wires need groups ONLY if they are involved in connections
        wires_needing_groups = {"left": set(), "right": set()}

        # Add splice wires (they always need groups)
        for splice in left_splices.keys():
            wires_needing_groups["left"].add(splice)
        for splice in right_splices.keys():
            wires_needing_groups["right"].add(splice)

        # Add source wires that connect to splices
        for source, target in connections["left_connections"].items():
            if target in connections["splice_wires"]:
                wires_needing_groups["left"].add(source)

        for source, target in connections["right_connections"].items():
            if target in connections["splice_wires"]:
                wires_needing_groups["right"].add(source)

        # Now apply groups ONLY to wires that need them
        # Left side
        for splice, assigned_group in left_splice_groups.items():
            # Splice wire gets group
            if splice in wires_needing_groups["left"]:
                tentative_groups[splice]["left"] = assigned_group

            # Source wires connected to this splice get same group
            if splice in left_splices:
                for source in left_splices[splice]:
                    if source in wires_needing_groups["left"]:
                        tentative_groups[source]["left"] = assigned_group

        # Right side
        for splice, assigned_group in right_splice_groups.items():
            if splice in wires_needing_groups["right"]:
                tentative_groups[splice]["right"] = assigned_group

            if splice in right_splices:
                for source in right_splices[splice]:
                    if source in wires_needing_groups["right"]:
                        tentative_groups[source]["right"] = assigned_group

        # Check what groups are actually used
        left_groups_used = set()
        right_groups_used = set()

        for wire_num in range(1, total_wires + 1):
            left_group = tentative_groups[wire_num]["left"]
            right_group = tentative_groups[wire_num]["right"]

            if left_group is not None:  # Only count if group was assigned
                left_groups_used.add(left_group)
            if right_group is not None:
                right_groups_used.add(right_group)

        # Check if we exceeded 3 groups (error condition)
        if len(left_groups_used) > 3:
            # This should not happen with our algorithm
            self.message_logger.log_message(
                "ERROR",
                f"Required {len(left_groups_used)} X-offset groups on left side. "
                f"Maximum allowed is 3.",
            )

        if len(right_groups_used) > 3:
            self.message_logger.log_message(
                "ERROR",
                f"Required {len(right_groups_used)} X-offset groups on right side. "
                f"Maximum allowed is 3.",
            )

        # Determine if group 0 should be written as empty
        # Group 0 is written as empty ONLY if:
        # 1. It's the only group used on that side
        # 2. AND it's group 0
        # Otherwise, group 0 is written as "0"

        write_left_0_as_empty = left_groups_used == {0} or left_groups_used == set()
        write_right_0_as_empty = right_groups_used == {0} or right_groups_used == set()

        # Build final result - convert None to empty string, numbers to string
        result = {}
        for wire_num in range(1, total_wires + 1):
            left_group = tentative_groups[wire_num]["left"]
            right_group = tentative_groups[wire_num]["right"]

            # Convert to string representation
            if left_group is None:
                left_str = ""  # No group needed
            elif left_group == 0 and write_left_0_as_empty:
                left_str = ""  # Group 0 written as empty when it's the only group
            else:
                left_str = str(left_group)

            if right_group is None:
                right_str = ""  # No group needed
            elif right_group == 0 and write_right_0_as_empty:
                right_str = ""  # Group 0 written as empty when it's the only group
            else:
                right_str = str(right_group)

            result[wire_num] = {"left": left_str, "right": right_str}

        return result

    def _process_single_wire(
        self,
        wire: WireData,
        wire_num: int,
        y_coordinates: Dict[int, int],
        connections: Dict[str, Any],
        groups: Dict[int, Dict[str, str]],
    ) -> Dict[str, Any]:
        """
        Process single wire and calculate all offsets and groups

        IMPORTANT: Splice wires are ONLY those that are ACTUAL targets of connections
        A wire is considered a splice if someone connects TO it

        Returns: Complete wire data dictionary with calculated values
        """
        # Get Y coordinate for this wire from pre-calculated coordinates
        y = y_coordinates.get(wire_num, wire_num)

        # Initialize Y offsets as empty (no offset)
        left_y_offset = ""
        right_y_offset = ""

        # Check if this wire is a REAL splice (target of ACTUAL connections)
        # A wire is a splice ONLY if someone connects TO it
        is_splice = wire_num in connections["splice_wires"]

        # Track if wire is target on specific sides
        is_left_target = False
        is_right_target = False

        # Check specifically for left and right target status
        for source, target, side in connections["all_connections"]:
            if target == wire_num:
                if side == "left":
                    is_left_target = True
                elif side == "right":
                    is_right_target = True

        # Calculate right side Y offset (if this wire connects TO another wire on right side)
        if wire_num in connections["right_connections"]:
            target = connections["right_connections"][wire_num]
            target_y = y_coordinates.get(target, target)
            offset = target_y - y

            # Store offset as string (positive or negative)
            right_y_offset = str(offset)

        # Calculate left side Y offset (if this wire connects TO another wire on left side)
        if wire_num in connections["left_connections"]:
            target = connections["left_connections"][wire_num]
            target_y = y_coordinates.get(target, target)
            offset = target_y - y

            # Store offset as string (positive or negative)
            left_y_offset = str(offset)

        # FIXED: Splice wires (targets) get offset = 0 ONLY if they are actual targets
        # Previous logic incorrectly gave offset=0 to all splices

        # For right side: if this wire is a target of right connections
        if is_right_target:
            # This wire is target of someone else's right connection
            # So it should have offset = 0 on right side
            # But only if it doesn't already have an offset from connecting to another wire
            if not right_y_offset:  # Only set if not already set
                right_y_offset = "0"

        # For left side: same logic
        if is_left_target:
            if not left_y_offset:  # Only set if not already set
                left_y_offset = "0"

        # Get X offsets (groups) - these might be empty for wires without connections
        # Groups dictionary contains string values: "", "0", "1", or "2"
        left_x_offset = groups[wire_num]["left"]
        right_x_offset = groups[wire_num]["right"]

        # FIXED: Additional check - wires without connections should not have groups
        # Even if groups dictionary has a value, we should clear it for wires not involved in connections
        has_left_connection = wire_num in connections["left_connections"]
        has_right_connection = wire_num in connections["right_connections"]

        # Clear groups for wires that don't need them
        # A wire needs group if:
        # 1. It has an outgoing connection (source)
        # 2. It's a splice (target)
        # 3. It has calculated Y offset (meaning it connects to something)

        needs_left_group = has_left_connection or is_left_target or left_y_offset != ""

        needs_right_group = (
            has_right_connection or is_right_target or right_y_offset != ""
        )

        # If wire doesn't need group, clear the group value
        if not needs_left_group and left_x_offset:
            left_x_offset = ""

        if not needs_right_group and right_x_offset:
            right_x_offset = ""

        # Get target wire numbers for connections (if any)
        left_target = connections["left_connections"].get(wire_num)
        right_target = connections["right_connections"].get(wire_num)

        # Build and return complete wire data dictionary
        return {
            "y": y,  # Y coordinate (1-based)
            "left_x_offset": left_x_offset,  # Left group (0, 1, 2 or "")
            "left_y_offset": left_y_offset,  # Left vertical offset (Y direction)
            "right_x_offset": right_x_offset,  # Right group (0, 1, 2 or "")
            "right_y_offset": right_y_offset,  # Right vertical offset (Y direction)
            "is_splice": is_splice,  # Is this wire a splice (target of connections)?
            "has_left_connection": has_left_connection,  # Has outgoing left connection
            "has_right_connection": has_right_connection,  # Has outgoing right connection
            "left_target": left_target,  # Target wire for left connection
            "right_target": right_target,  # Target wire for right connection
            "is_left_target": is_left_target,  # Is this wire a target on left side
            "is_right_target": is_right_target,  # Is this wire a target on right side
            # Additional useful information for debugging
            "signal_name": wire.signal_name,
            "wire_type": wire.wire_type,
            "left_connector": wire.left_connector,
            "right_connector": wire.right_connector,
        }

    def _get_connector_name(self, connector_pin: str) -> str:
        """
        Extract connector name from connector/pin format

        Examples:
        - "P1/A1" → "P1"
        - "CONN/X" → "CONN"
        - "PIN" → "" (no slash)
        - "" → ""

        Returns: Connector name or empty string
        """
        if not connector_pin or "/" not in connector_pin:
            return ""

        parts = connector_pin.split("/", 1)
        return parts[0].strip()

    def _get_group_name(self, connector_pin: str, wires: List[WireData],
                        side: str) -> str:
        """
        Get group name according to TCL GetGroupName logic

        Rules:
        1. If pin has no connector (no slash) and matches A1-D9: return "GROUP_LETTER"
        2. If pin has connector and ALL pins of this connector are A1-D9:
           return "CONNECTOR/GROUP_LETTER"
        3. If pin has connector but not all pins are A1-D9: return "CONNECTOR"
        4. Otherwise: return "" or connector name

        Args:
            connector_pin: Pin name in format "CONNECTOR/PIN" or just "PIN"
            wires: List of all wires for checking all pins of connector
            side: "left" or "right" for context

        Returns: Group identifier string
        """
        if not connector_pin:
            return ""

        # Parse connector and pin name
        if "/" in connector_pin:
            parts = connector_pin.split("/", 1)
            connector_name = parts[0].strip()
            pin_name = parts[1].strip() if len(parts) > 1 else ""
            has_connector = True
        else:
            connector_name = ""
            pin_name = connector_pin.strip()
            has_connector = False

        # Check if pin matches group pattern A1-A9, B1-B9, C1-C9, D1-D9
        # Pattern: exactly one letter A-D followed by exactly one digit 1-9
        group_match = re.match(r'^([A-D])[1-9]$', pin_name.upper())

        # Not a group pin
        if not group_match:
            if has_connector:
                return connector_name
            else:
                return ""

        group_letter = group_match.group(1)  # A, B, C, or D

        # For pins without connector name - return group letter only
        if not has_connector:
            return group_letter

        # Analyze all pins of this connector to check if ALL are valid groups
        all_pins_valid_groups = True

        for wire in wires:
            # Get pin for this side
            if side == "left":
                side_pin = wire.left_connector
            else:
                side_pin = wire.right_connector

            if not side_pin:
                continue

            if "/" in side_pin:
                side_parts = side_pin.split("/", 1)
                side_connector = side_parts[0].strip()
                side_pin_name = side_parts[1].strip() if len(side_parts) > 1 else ""

                # Check if this pin belongs to the same connector
                if side_connector == connector_name:
                    # Check if pin matches group pattern
                    side_match = re.match(r'^([A-D])[1-9]$', side_pin_name.upper())
                    if not side_match:
                        # Found a pin in this connector that is NOT a valid group
                        all_pins_valid_groups = False
                        break

        # Return appropriate identifier
        if all_pins_valid_groups:
            # All pins of this connector are valid groups
            return f"{connector_name}/{group_letter}"
        else:
            # Not all pins are valid groups - return connector only
            return connector_name
