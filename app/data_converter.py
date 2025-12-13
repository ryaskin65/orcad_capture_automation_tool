# RIGa&DeepSeek 13.12.2025

import os
from typing import Dict, List, Tuple, Optional
from openpyxl import Workbook, load_workbook


class DataConverter:
    def __init__(self, message_logger):
        self.message_logger = message_logger
        self.errors = []
        self.warnings = []

        # Define input and output column mappings
        self.input_columns = {
            "Signal name": "Signal name",
            "Left connector": "Left connector",
            "Right connector": "Right connector",
            "Left side IN/OUT": "Left side IN/OUT",
            "Type": "Type",
            "Left wire width, Gauge": "Left wire width, Gauge",
            "Color": "Color",
            "Right wire width, Gauge": "Right wire width, Gauge",
            "Connect to right wire with number": "Connect to right wire with number",
            "Connect to left wire with number": "Connect to left wire with number"
        }

        self.output_columns = [
            "Signal name",
            "Right connector",
            "Left connector",
            "Right side IN/OUT",
            "Type",
            "Left wire width, Gauge",
            "Color",
            "Right wire width, Gauge",
            "Right wire offset",
            "Right group",
            "Left wire offset",
            "Left group"
        ]

        self.header_fields = [
            "ProjectNumber", "NumberCable", "NameLeftSide", "NameRightSide",
            "Title", "PartNumber", "DocumentNumber", "Revision"
        ]

        # Constants for A3 page layout
        self.STEP_XY = 2.54
        self.A3_WIDTH = 420.0
        self.A3_HEIGHT = 297.0
        self.STEP_WIRE_Y = self.STEP_XY * 2
        self.START_WIRE_Y = self.STEP_XY * 8
        self.END_WIRE_Y = self.A3_HEIGHT - self.STEP_XY * 8

    def convert_excel_file(self, input_path: str, output_path: str) -> Tuple[bool, List, List]:
        """
        Convert Excel file from input format to output format with validation and auto-processing

        Returns: (success, errors, warnings)
        """
        self.errors = []
        self.warnings = []

        if not os.path.exists(input_path):
            self.errors.append(f"Input file does not exist: {input_path}")
            return False, self.errors, self.warnings

        try:
            # Load input workbook
            input_wb = load_workbook(input_path)
            input_ws = input_wb.active

            # Parse input data
            input_data = self._parse_input_worksheet(input_ws)
            if not input_data:
                self.errors.append("No valid data found in input file")
                return False, self.errors, self.warnings

            # Validate data structure
            is_valid, validation_errors, validation_warnings = self._validate_data_structure(input_data)
            self.errors.extend(validation_errors)
            self.warnings.extend(validation_warnings)

            if not is_valid:
                return False, self.errors, self.warnings

            # Convert data format and auto-process
            success, converted_data = self._convert_and_process_data(input_data)
            if not success:
                return False, self.errors, self.warnings

            # Create output workbook
            output_wb = Workbook()
            output_ws = output_wb.active
            output_ws.title = "Cable Data"

            # Write converted data to output
            self._write_output_worksheet(output_ws, converted_data)

            # Save output file
            output_wb.save(output_path)
            self.message_logger.log_message('SUCCESS', f"File converted successfully: {output_path}")

            return True, self.errors, self.warnings

        except Exception as e:
            self.errors.append(f"Conversion error: {str(e)}")
            return False, self.errors, self.warnings

    def _parse_input_worksheet(self, worksheet) -> Dict:
        """Parse input worksheet and extract structured data"""
        data = {
            'headers': {},
            'pages': {}
        }

        current_section = 'headers'
        current_page = None
        column_mapping = {}
        header_found = False

        for row in worksheet.iter_rows(values_only=True):
            if not row or not any(cell for cell in row if cell and str(cell).strip()):
                continue

            first_cell = str(row[0]).strip() if row[0] else ""

            # Detect PAGE section
            if first_cell.upper() == "PAGE":
                current_section = 'pages'
                if len(row) > 1 and row[1]:
                    current_page = str(row[1]).strip()
                    data['pages'][current_page] = {
                        'wire_headers': [],
                        'wires': []
                    }
                    header_found = False
                    column_mapping = {}
                continue

            # Process header section (before first PAGE)
            if current_section == 'headers':
                if first_cell in self.header_fields and len(row) > 1:
                    data['headers'][first_cell] = str(row[1]) if row[1] else ""

            # Process page section
            elif current_section == 'pages' and current_page:
                # Detect wire headers row
                if first_cell == "Signal name" and not header_found:
                    header_found = True
                    data['pages'][current_page]['wire_headers'] = [str(cell).strip() if cell else "" for cell in row]

                    # Create column mapping for this page
                    column_mapping = self._create_column_mapping(data['pages'][current_page]['wire_headers'])
                    if not column_mapping:
                        self.errors.append(f"Page '{current_page}': Required columns not found")

                # Process wire data rows
                elif header_found and first_cell and first_cell not in self.header_fields:
                    wire_data = self._parse_wire_row(row, column_mapping)
                    if wire_data:
                        data['pages'][current_page]['wires'].append(wire_data)

        return data

    def _create_column_mapping(self, headers: List[str]) -> Dict[str, int]:
        """Create mapping from column names to indices"""
        mapping = {}

        for i, header in enumerate(headers):
            if not header:
                continue

            exact_header = str(header).strip()
            clean_header = exact_header.lower()

            # Map exact column names from input file
            if clean_header == "signal name":
                mapping["Signal name"] = i
            elif clean_header == "right connector":
                mapping["Right connector"] = i
            elif clean_header == "left connector":
                mapping["Left connector"] = i
            elif clean_header == "left side in/out":
                mapping["Left side IN/OUT"] = i
            elif clean_header == "type":
                mapping["Type"] = i
            elif clean_header == "left wire width, gauge":
                mapping["Left wire width, Gauge"] = i
            elif clean_header == "color":
                mapping["Color"] = i
            elif clean_header == "right wire width, gauge":
                mapping["Right wire width, Gauge"] = i
            elif clean_header == "connect to right wire with number":
                mapping["Connect to right wire with number"] = i
            elif clean_header == "connect to left wire with number":
                mapping["Connect to left wire with number"] = i
            elif clean_header == "left wire width gauge":
                mapping["Left wire width, Gauge"] = i
            elif clean_header == "right wire width gauge":
                mapping["Right wire width, Gauge"] = i

        return mapping

    def _parse_wire_row(
        self, row: tuple, column_mapping: Dict[str, int]
    ) -> Optional[Dict]:
        """Parse a single wire data row into a dictionary with all fields"""
        wire_data = {}

        # Initialize all possible fields
        all_fields = [
            "Signal name",
            "Left connector",
            "Right connector",
            "Left side IN/OUT",
            "Type",
            "Left wire width, Gauge",
            "Color",
            "Right wire width, Gauge",
            "Connect to right wire with number",
            "Connect to left wire with number",
        ]

        for field in all_fields:
            wire_data[field] = ""

        # Fill data from row
        for field_name, col_index in column_mapping.items():
            if col_index < len(row):
                value = row[col_index]
                if value is not None:
                    wire_data[field_name] = str(value).strip()

        if not wire_data.get("Signal name", "").strip():
            return None

        return wire_data

    def _validate_data_structure(self, data: Dict) -> Tuple[bool, List, List]:
        """Validate cable data structure"""
        errors = []
        warnings = []

        if not data.get('pages'):
            errors.append("No pages found in cable data")
            return False, errors, warnings

        required_headers = [
            "Signal name",
            "Right connector",
            "Left connector",
        ]

        for page_name, page_data in data['pages'].items():
            headers = page_data.get('wire_headers', [])
            wires = page_data.get('wires', [])

            # Check required headers
            for req_header in required_headers:
                if req_header not in headers:
                    errors.append(
                        f"Page '{page_name}': Missing required header '{req_header}'"
                    )

            # Check wire data exists
            if not wires:
                warnings.append(f"Page '{page_name}': No wire data found")

            # Validate wire type rules
            wire_errors, wire_warnings = self._validate_wire_rules(page_name, wires)
            errors.extend(wire_errors)
            warnings.extend(wire_warnings)

            # Validate connector pins
            pin_errors, pin_warnings = self._validate_connector_pins(page_name, wires)
            errors.extend(pin_errors)
            warnings.extend(pin_warnings)

            # Validate signal names
            signal_errors, signal_warnings = self._validate_signal_names(page_name, wires)
            errors.extend(signal_errors)
            warnings.extend(signal_warnings)

            # Validate page capacity
            capacity_errors, capacity_warnings = self._validate_page_capacity(page_name, wires)
            errors.extend(capacity_errors)
            warnings.extend(capacity_warnings)

        return len(errors) == 0, errors, warnings

    def _validate_wire_rules(self, page_name: str, wires: List[Dict]) -> Tuple[List, List]:
        """Validate wire type rules (twisted pairs, etc.)"""
        errors = []
        warnings = []

        i = 0
        while i < len(wires):
            wire = wires[i]
            wire_type = wire.get("Type", "").upper()

            if wire_type in ["TWISTED", "TW", "SHIELDED TWISTED", "ST"]:
                if i + 1 >= len(wires):
                    errors.append(
                        f"Page '{page_name}', wire '{wire.get('Signal name', '')}': "
                        f"Twisted pair '{wire_type}' must have exactly 2 wires"
                    )
                    break

                next_wire = wires[i + 1]
                next_wire_type = next_wire.get("Type", "").upper()

                if next_wire_type not in ["TWISTED", "TW", "SHIELDED TWISTED", "ST"]:
                    errors.append(
                        f"Page '{page_name}', wire '{wire.get('Signal name', '')}': "
                        f"Twisted pair must consist of 2 consecutive wires of the same type"
                    )

                i += 2
            else:
                i += 1

        return errors, warnings

    def _validate_connector_pins(self, page_name: str, wires: List[Dict]) -> Tuple[List, List]:
        """Validate connector pin names and uniqueness"""
        errors = []
        warnings = []

        page_right_pins = {}
        page_left_pins = {}

        for wire in wires:
            # Validate right connector pins
            right_connector = wire.get("Right connector", "")
            if right_connector:
                pin_errors = self._validate_pin_format(
                    right_connector, page_name, wire.get("Signal name", ""), "right"
                )
                errors.extend(pin_errors)

                connector_name, pin_name = self._split_connector_pin(right_connector)
                if connector_name and pin_name:
                    if connector_name not in page_right_pins:
                        page_right_pins[connector_name] = set()
                    if pin_name in page_right_pins[connector_name]:
                        errors.append(
                            f"Page '{page_name}': Duplicate pin '{right_connector}' "
                            f"in right connector '{connector_name}'"
                        )
                    page_right_pins[connector_name].add(pin_name)

            # Validate left connector pins
            left_connector = wire.get("Left connector", "")
            if left_connector:
                pin_errors = self._validate_pin_format(
                    left_connector, page_name, wire.get("Signal name", ""), "left"
                )
                errors.extend(pin_errors)

                connector_name, pin_name = self._split_connector_pin(left_connector)
                if connector_name and pin_name:
                    if connector_name not in page_left_pins:
                        page_left_pins[connector_name] = set()
                    if pin_name in page_left_pins[connector_name]:
                        errors.append(
                            f"Page '{page_name}': Duplicate pin '{left_connector}' "
                            f"in left connector '{connector_name}'"
                        )
                    page_left_pins[connector_name].add(pin_name)

        return errors, warnings

    def _validate_pin_format(self, pin_name: str, page_name: str, signal_name: str, side: str) -> List[str]:
        """Validate pin name format"""
        errors = []

        if not pin_name:
            return errors

        if "/" not in pin_name:
            errors.append(
                f"Page '{page_name}', signal '{signal_name}': "
                f"{side} connector pin '{pin_name}' must be in format 'CONNECTOR_NAME/PIN_NAME'"
            )
            return errors

        parts = pin_name.split("/")
        if len(parts) != 2:
            errors.append(
                f"Page '{page_name}', signal '{signal_name}': "
                f"{side} connector pin '{pin_name}' must be in format 'CONNECTOR_NAME/PIN_NAME'"
            )
        elif not parts[0] or not parts[1]:
            errors.append(
                f"Page '{page_name}', signal '{signal_name}': "
                f"{side} connector pin '{pin_name}' has empty connector or pin name"
            )

        return errors

    def _split_connector_pin(
        self, connector_pin: str
    ) -> Tuple[Optional[str], Optional[str]]:
        """Split connector/pin into separate parts"""
        if not connector_pin or "/" not in connector_pin:
            return None, None

        parts = connector_pin.split("/", 1)  # Split only on first "/"
        connector_name = parts[0].strip()
        pin_name = parts[1].strip() if len(parts) > 1 else ""

        return connector_name, pin_name

    def _validate_signal_names(self, page_name: str, wires: List[Dict]) -> Tuple[List, List]:
        """Validate signal name uniqueness"""
        errors = []
        warnings = []

        page_signals = set()

        for wire in wires:
            signal_name = wire.get("Signal name", "")
            if not signal_name or signal_name.upper() == "SPACE":
                continue

            if signal_name in page_signals:
                errors.append(
                    f"Page '{page_name}': Duplicate signal name '{signal_name}'"
                )

            page_signals.add(signal_name)

        return errors, warnings

    def _validate_page_capacity(self, page_name: str, wires: List[Dict]) -> Tuple[List, List]:
        """Validate that page doesn't exceed wire capacity"""
        errors = []
        warnings = []

        max_wires = self._calculate_max_wires()
        wire_count = len([w for w in wires if w.get("Signal name", "").upper() != "SPACE"])

        if wire_count > max_wires:
            errors.append(
                f"Page '{page_name}': Too many wires ({wire_count}). "
                f"Maximum allowed is {max_wires}"
            )

        return errors, warnings

    def _calculate_max_wires(self) -> int:
        """Calculate maximum number of wires that can fit on A3 page"""
        available_height = self.END_WIRE_Y - self.START_WIRE_Y
        max_wires = int(available_height / self.STEP_WIRE_Y) - 2
        return max(1, max_wires)

    def _convert_and_process_data(self, input_data: Dict) -> Tuple[bool, List[List]]:
        """Convert data format and auto-process with wire parameters calculation"""
        converted_data = []

        # Add header rows
        for header_field in self.header_fields:
            if header_field in input_data['headers']:
                converted_data.append([header_field, input_data['headers'][header_field]])

        # Add empty row before pages
        converted_data.append([])

        # Process each page
        for page_name, page_data in input_data['pages'].items():
            # Add PAGE row
            converted_data.append(["PAGE", page_name])

            # Add output headers
            converted_data.append(self.output_columns)

            # Convert wire data and calculate parameters
            wires = page_data.get('wires', [])
            success, processed_wires = self._calculate_wire_parameters(wires)
            if not success:
                return False, []

            converted_data.extend(processed_wires)

            # Add empty row between pages
            converted_data.append([])

        return True, converted_data

    def _calculate_wire_parameters(self, wires: List[Dict]) -> Tuple[bool, List[List]]:
        """Calculate automatic offsets, splices, and groups based on layout rules"""
        # First, calculate visual wire numbers considering twisted pairs
        visual_wire_numbers = self._calculate_visual_wire_numbers(wires)

        # Calculate connection-based offsets and groups using visual numbers
        connection_success, processed_wires = self._calculate_connection_parameters(
            wires, visual_wire_numbers
        )
        if not connection_success:
            return False, []

        return True, processed_wires

    def _calculate_visual_wire_numbers(self, wires: List[Dict]) -> Dict[int, int]:
        """Calculate coordinate Y values considering twisted pairs and connector/group changes"""
        coordinate_y = {}
        current_coordinate = 1  # Start coordinate

        # Group wires by connectors AND pin groups
        connector_groups = self._group_wires_by_connectors(wires)

        i = 0
        while i < len(wires):
            wire = wires[i]
            wire_num = i + 1

            # Check if current wire starts a new connector/pin group
            current_group = self._get_connector_group(wire_num, connector_groups)
            if current_group and wire_num == current_group[0] and wire_num > 1:
                # This wire starts a new connector or pin group, add +3 offset
                # Even if both sides change simultaneously, we add only +3, not +6
                current_coordinate += 3

            # Handle twisted pairs
            wire_type = wire.get("Type", "").upper()
            if wire_type in ["TWISTED", "TW", "SHIELDED TWISTED", "ST"]:
                # First wire of twisted pair
                coordinate_y[i + 1] = current_coordinate
                current_coordinate += 1

                # Second wire of twisted pair (if exists)
                if i + 1 < len(wires):
                    coordinate_y[i + 2] = current_coordinate
                    current_coordinate += 1

                # Check if twisted pair is LAST in its connector/pin group
                is_last_in_group = False
                if current_group:
                    last_wire_in_group = current_group[-1]
                    # Check if the second wire of twisted pair is the last in group
                    if i + 2 == last_wire_in_group:
                        is_last_in_group = True

                # Add +1 offset AFTER twisted pair ONLY if NOT last in connector/group
                i += 2
                if not is_last_in_group:
                    current_coordinate += 1  # Extra offset after twisted pair
            else:
                # Regular wire
                coordinate_y[i + 1] = current_coordinate
                current_coordinate += 1
                i += 1

        return coordinate_y

    def _extract_pin_group(self, pin_name: str) -> str:
        """Extract pin group from pin name (A, B, C, D for groups 1-9)"""
        if not pin_name:
            return ""

        # Pin must be exactly 2 characters: letter + number
        if len(pin_name) == 2:
            letter = pin_name[0].upper()
            number_char = pin_name[1]

            # Check if letter is A, B, C, D and number is 1-9
            if letter in ["A", "B", "C", "D"] and number_char.isdigit():
                number = int(number_char)
                if 1 <= number <= 9:
                    return letter  # Return group letter (A, B, C, D)

        return ""  # Not a group pin

    def _group_wires_by_connectors(self, wires: List[Dict]) -> List[List[int]]:
        """Group wire numbers by their connectors and pin groups"""
        groups = []
        current_group = []
        prev_left_connector = None
        prev_right_connector = None
        prev_left_group = None
        prev_right_group = None

        for i, wire in enumerate(wires):
            wire_num = i + 1
            left_connector = wire.get("Left connector", "")
            right_connector = wire.get("Right connector", "")

            # Extract connector names and pin groups
            left_conn_name, left_pin_name = self._split_connector_pin(left_connector)
            right_conn_name, right_pin_name = self._split_connector_pin(right_connector)

            # Extract pin group (A, B, C, D)
            left_pin_group = self._extract_pin_group(left_pin_name)
            right_pin_group = self._extract_pin_group(right_pin_name)

            # Check if connector OR pin group changed on EITHER side
            connector_or_group_changed = False

            # LEFT side check
            if prev_left_connector is not None and left_conn_name:
                # Case 1: Connector name changed
                if left_conn_name != prev_left_connector:
                    connector_or_group_changed = True
                # Case 2: Same connector but pin group changed AND previous had group
                elif left_conn_name == prev_left_connector:
                    if prev_left_group and left_pin_group:
                        if left_pin_group != prev_left_group:
                            connector_or_group_changed = True
                    # Case 3: Previous had no group, current has group (or vice versa)
                    elif (prev_left_group and not left_pin_group) or (
                        not prev_left_group and left_pin_group
                    ):
                        connector_or_group_changed = True

            # RIGHT side check
            if prev_right_connector is not None and right_conn_name:
                # Case 1: Connector name changed
                if right_conn_name != prev_right_connector:
                    connector_or_group_changed = True
                # Case 2: Same connector but pin group changed AND previous had group
                elif right_conn_name == prev_right_connector:
                    if prev_right_group and right_pin_group:
                        if right_pin_group != prev_right_group:
                            connector_or_group_changed = True
                    # Case 3: Previous had no group, current has group (or vice versa)
                    elif (prev_right_group and not right_pin_group) or (
                        not prev_right_group and right_pin_group
                    ):
                        connector_or_group_changed = True

            # If either side changed, start new group
            if connector_or_group_changed and current_group:
                groups.append(current_group)
                current_group = []

            # Add wire to current group
            current_group.append(wire_num)

            # Update previous values (only if connector exists)
            if left_conn_name:
                prev_left_connector = left_conn_name
                prev_left_group = left_pin_group

            if right_conn_name:
                prev_right_connector = right_conn_name
                prev_right_group = right_pin_group

        # Add last group if not empty
        if current_group:
            groups.append(current_group)

        return groups

    def _get_connector_group(
        self, wire_num: int, connector_groups: List[List[int]]
    ) -> List[int]:
        """Get connector/pin group for a specific wire number"""
        for group in connector_groups:
            if wire_num in group:
                return group
        return []

    def _extract_connector_name(self, connector_pin: str) -> str:
        """Extract connector name from connector/pin format"""
        if not connector_pin or "/" not in connector_pin:
            return ""

        parts = connector_pin.split("/")
        return parts[0].strip()

    # def _calculate_layout_offsets(self, wires: List[List]) -> Tuple[bool, List[List]]:
    #     """Calculate layout-based offsets according to wiring rules"""
    #     processed_wires = []
    #
    #     for i, wire in enumerate(wires):
    #         # Keep the connection-based offsets, only apply additional layout rules if needed
    #         processed_wire = wire.copy()
    #
    #         # If no connection-based offset, apply basic layout rules
    #         if (
    #             not processed_wire[8] and not processed_wire[10]
    #         ):  # No right or left offsets
    #             # Apply twisted pair spacing if previous wire was twisted pair
    #             if i > 0 and wires[i - 1][4].upper() in [
    #                 "TWISTED",
    #                 "TW",
    #                 "SHIELDED TWISTED",
    #                 "ST",
    #             ]:
    #                 processed_wire[8] = "1"  # Right offset
    #                 processed_wire[10] = "1"  # Left offset
    #
    #         processed_wires.append(processed_wire)
    #
    #     return True, processed_wires

    # def _calculate_connector_offset(self, current_connector: str, prev_connector: str) -> str:
    #     """Calculate offset based on connector change"""
    #     if not current_connector:
    #         return ""
    #
    #     current_connector_name = self._get_connector_name(current_connector)
    #
    #     if prev_connector and current_connector_name != prev_connector:
    #         return "2"  # Two steps after connector name change
    #     else:
    #         return ""   # No offset for same connector

    # def _get_connector_name(self, connector_pin: str) -> str:
    #     """Extract connector name from connector/pin format"""
    #     if not connector_pin or "/" not in connector_pin:
    #         return ""
    #     return connector_pin.split("/")[0].strip()

    def _calculate_groups(
        self, connection_map: Dict, total_wires: int
    ) -> Dict[int, int]:
        """Calculate groups to prevent short circuits between multiple splices"""
        groups = {}
        current_group = 0  # Start from 0 as per requirement
        visited = set()

        # First, find all wires involved in connections
        connected_wires = set()
        for wire_num in range(1, total_wires + 1):
            if wire_num in connection_map or any(
                wire_num in sources for sources in connection_map.values()
            ):
                connected_wires.add(wire_num)

        # If no wires are connected, return empty groups
        if not connected_wires:
            return groups

        # Group connected wires
        for wire_num in connected_wires:
            if wire_num in visited:
                continue

            # Start a new group
            queue = [wire_num]
            while queue:
                current = queue.pop(0)
                if current in visited:
                    continue

                visited.add(current)
                groups[current] = current_group

                # Add wires that connect TO this wire
                if current in connection_map:
                    for src in connection_map[current]:
                        if src not in visited:
                            queue.append(src)

                # Add wires that this wire connects TO
                for target, sources in connection_map.items():
                    if current in sources and target not in visited:
                        queue.append(target)

            current_group += 1

        # Check if we have only one group (group 0) - in this case we won't write group numbers
        unique_groups = set(groups.values())
        if len(unique_groups) == 1 and 0 in unique_groups:
            # Only one group (group 0), so we clear all groups (won't write numbers)
            groups = {}

        return groups

    def _calculate_connection_parameters(
        self, wires: List[Dict], visual_numbers: Dict[int, int]
    ) -> Tuple[bool, List[List]]:
        """Calculate connection-based offsets and groups using coordinate Y values"""
        left_connections = {}  # source_wire_num -> target_wire_num for left side
        right_connections = {}  # source_wire_num -> target_wire_num for right side

        # Create mapping: wire number -> coordinate Y
        wire_to_coordinate = visual_numbers  # This contains coordinate Y for each wire

        # Collect all connections using WIRE NUMBERS (not coordinates)
        # User enters wire numbers in Excel, not coordinates
        for i, wire in enumerate(wires):
            wire_num = i + 1
            signal_name = wire.get("Signal name", "")

            # LEFT connections (Connect to left wire with number)
            connect_left_str = wire.get("Connect to left wire with number", "")
            if connect_left_str and str(connect_left_str).strip():
                try:
                    connect_left = str(connect_left_str).strip()
                    if connect_left:
                        # User enters TARGET WIRE NUMBER (not coordinate)
                        target_wire_num = int(connect_left)

                        # Validate target wire number
                        if 1 <= target_wire_num <= len(wires):
                            if target_wire_num != wire_num:
                                left_connections[wire_num] = target_wire_num
                            else:
                                self.warnings.append(
                                    f"Wire '{signal_name}': Cannot connect to itself (left)"
                                )
                        else:
                            self.warnings.append(
                                f"Wire '{signal_name}': Invalid left connection wire number '{target_wire_num}'"
                            )
                except ValueError:
                    # Not a number, might be empty or other value
                    self.warnings.append(
                        f"Wire '{signal_name}': Invalid left connection value '{connect_left_str}'"
                    )

            # RIGHT connections (Connect to right wire with number)
            connect_right_str = wire.get("Connect to right wire with number", "")
            if connect_right_str and str(connect_right_str).strip():
                try:
                    connect_right = str(connect_right_str).strip()
                    if connect_right:
                        # User enters TARGET WIRE NUMBER (not coordinate)
                        target_wire_num = int(connect_right)

                        # Validate target wire number
                        if 1 <= target_wire_num <= len(wires):
                            if target_wire_num != wire_num:
                                right_connections[wire_num] = target_wire_num
                            else:
                                self.warnings.append(
                                    f"Wire '{signal_name}': Cannot connect to itself (right)"
                                )
                        else:
                            self.warnings.append(
                                f"Wire '{signal_name}': Invalid right connection wire number '{target_wire_num}'"
                            )
                except ValueError:
                    # Not a number, might be empty or other value
                    self.warnings.append(
                        f"Wire '{signal_name}': Invalid right connection value '{connect_right_str}'"
                    )

        # Create connection map for grouping (wire number based)
        connection_map = {}

        # Process left connections
        for source_wire, target_wire in left_connections.items():
            if target_wire not in connection_map:
                connection_map[target_wire] = set()
            connection_map[target_wire].add(source_wire)

        # Process right connections
        for source_wire, target_wire in right_connections.items():
            if target_wire not in connection_map:
                connection_map[target_wire] = set()
            connection_map[target_wire].add(source_wire)

        # Calculate groups to prevent short circuits
        groups = self._calculate_groups(connection_map, len(wires))

        # Process each wire to calculate offsets using COORDINATES
        processed_wires = []
        for i, wire in enumerate(wires):
            wire_num = i + 1
            processed_wire = self._process_single_wire_connections(
                wire,
                wire_num,
                left_connections,
                right_connections,
                groups,
                wire_to_coordinate,  # This is actually coordinate Y mapping
            )
            processed_wires.append(processed_wire)

        return True, processed_wires

    def _process_single_wire_connections(
        self,
        wire: Dict,
        wire_num: int,
        left_connections: Dict,
        right_connections: Dict,
        groups: Dict,
        coordinate_mapping: Dict[int, int],
    ) -> List:
        """Process a single wire for connection-based parameters using Y coordinates"""
        signal_name = wire.get("Signal name", "")

        # Get Y coordinate for current wire
        current_coordinate = coordinate_mapping.get(wire_num, wire_num)

        # Initialize default values
        right_offset = ""
        left_offset = ""
        right_group = ""
        left_group = ""

        # Check if this wire is a SPLICE (has wires connecting TO it)
        # A splice wire is a TARGET of connections
        is_splice_right = False
        for source_wire, target_wire in right_connections.items():
            if target_wire == wire_num:
                is_splice_right = True
                break

        is_splice_left = False
        for source_wire, target_wire in left_connections.items():
            if target_wire == wire_num:
                is_splice_left = True
                break

        # RIGHT offset (if this wire has outgoing connection to right side)
        if wire_num in right_connections:
            target_wire_num = right_connections[wire_num]
            target_coordinate = coordinate_mapping.get(target_wire_num, target_wire_num)
            # Calculate offset: target Y coordinate - current Y coordinate
            offset = target_coordinate - current_coordinate
            right_offset = str(offset)

        # LEFT offset (if this wire has outgoing connection to left side)
        if wire_num in left_connections:
            target_wire_num = left_connections[wire_num]
            target_coordinate = coordinate_mapping.get(target_wire_num, target_wire_num)
            # Calculate offset: target Y coordinate - current Y coordinate
            offset = target_coordinate - current_coordinate
            left_offset = str(offset)

        # NEW RULE: If wire is a SPLICE (other wires connect TO it), set offset to 0
        # But only if it doesn't have its own outgoing connection
        if is_splice_right and wire_num not in right_connections:
            right_offset = "0"

        if is_splice_left and wire_num not in left_connections:
            left_offset = "0"

        # Determine groups
        if wire_num in groups:
            group_id = groups[wire_num]

            # Check connections to determine group placement
            has_right_connection = wire_num in right_connections or is_splice_right
            has_left_connection = wire_num in left_connections or is_splice_left

            # If wire has connection on right side or is splice on right, group on right side
            if has_right_connection and group_id != 0:
                right_group = str(group_id)

            # If wire has connection on left side or is splice on left, group on left side
            if has_left_connection and group_id != 0:
                left_group = str(group_id)

        # Convert IN/OUT direction (IN ↔ OUT)
        right_in_out = self._convert_in_out_direction(wire)

        # Get wire properties
        wire_type = wire.get("Type", "")
        left_gauge = wire.get("Left wire width, Gauge", "")
        color = wire.get("Color", "")
        right_gauge = wire.get("Right wire width, Gauge", "")

        return [
            signal_name,
            wire.get("Right connector", ""),
            wire.get("Left connector", ""),
            right_in_out,
            wire_type,
            left_gauge,
            color,
            right_gauge,
            right_offset,
            right_group,
            left_offset,
            left_group,
        ]

    def _convert_in_out_direction(self, wire: Dict) -> str:
        """Convert Left side IN/OUT to Right side IN/OUT"""
        left_in_out = wire.get('Left side IN/OUT', '').upper()

        if left_in_out == "IN":
            return "OUT"
        elif left_in_out == "OUT":
            return "IN"
        else:
            return left_in_out

    def _write_output_worksheet(self, worksheet, converted_data: List[List]):
        """Write converted data to output worksheet"""
        for row_idx, row_data in enumerate(converted_data, 1):
            for col_idx, value in enumerate(row_data, 1):
                worksheet.cell(row=row_idx, column=col_idx, value=value)

    def get_conversion_summary(self) -> str:
        """Get formatted conversion summary"""
        summary = []

        if self.errors:
            summary.append("CONVERSION ERRORS:")
            for error in self.errors:
                summary.append(f"  ❌ {error}")

        if self.warnings:
            summary.append("CONVERSION WARNINGS:")
            for warning in self.warnings:
                summary.append(f"  ⚠️  {warning}")

        if not self.errors and not self.warnings:
            summary.append("✅ File conversion completed successfully")
            summary.append("📝 Data validated and auto-processed with offsets and groups")

        return "\n".join(summary)
