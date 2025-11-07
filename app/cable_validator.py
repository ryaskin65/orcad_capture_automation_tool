# RIGa&DeepSeek 07.11.2025

class CableValidator:
    def __init__(self, message_logger):
        self.message_logger = message_logger
        self.errors = []
        self.warnings = []

    def validate_cable_data(self, data):
        """
        Main validation function for cable data
        Returns: (is_valid, errors, warnings)
        """
        self.errors = []
        self.warnings = []

        if not data:
            self.errors.append("No data provided for validation")
            return False, self.errors, self.warnings

        # Extract pages and wires
        pages_data = self._extract_pages_and_wires(data)

        # Validate structure
        self._validate_structure(pages_data)

        # Validate wire rules
        self._validate_wire_rules(pages_data)

        # Validate connector pins (separate for left and right)
        self._validate_connector_pins(pages_data)

        # Validate signal names
        self._validate_signal_names(pages_data)

        # Validate page capacity
        self._validate_page_capacity(pages_data)

        # Validate wire offsets
        self._validate_wire_offsets(pages_data)

        return len(self.errors) == 0, self.errors, self.warnings

    def _extract_pages_and_wires(self, data):
        """Extract pages and wire data from raw data"""
        pages_data = {}
        current_page = None
        header_found = False
        wire_headers = []

        for row in data:
            if not row or not any(cell and str(cell).strip() for cell in row):
                continue

            first_cell = str(row[0]).strip().upper() if row[0] else ""

            if first_cell == "PAGE" and len(row) > 1:
                page_name = str(row[1]).strip()
                current_page = page_name
                pages_data[page_name] = {
                    'wires': [],
                    'headers': []
                }
                header_found = False
                wire_headers = []

            elif first_cell == "SIGNAL NAME" and current_page:
                # This is the header row for wires
                wire_headers = [str(cell).strip() for cell in row]
                header_found = True
                pages_data[current_page]['headers'] = wire_headers

            elif header_found and current_page and first_cell and first_cell not in [
                "PROJECTNUMBER", "NUMBERCABLE", "NAMELEFTSIDE", "NAMERIGHTSIDE",
                "TITLE", "PARTNUMBER", "DOCUMENTNUMBER", "REVISION", "EDITTITLEBLOCK", "PAGE"
            ]:
                # This is a wire data row
                wire_data = {}
                for i, header in enumerate(wire_headers):
                    if i < len(row):
                        wire_data[header] = str(row[i]).strip() if row[i] else ""
                    else:
                        wire_data[header] = ""

                pages_data[current_page]['wires'].append(wire_data)

        return pages_data

    def _validate_structure(self, pages_data):
        """Validate basic structure of cable data"""
        if not pages_data:
            self.errors.append("No pages found in cable data")
            return

        required_headers = ["Signal name", "Right connector", "Left connector", "Right side IN/OUT"]

        for page_name, page_data in pages_data.items():
            headers = page_data.get('headers', [])
            wires = page_data.get('wires', [])

            # Check required headers
            for req_header in required_headers:
                if req_header not in headers:
                    self.errors.append(f"Page '{page_name}': Missing required header '{req_header}'")

            # Check wire data exists
            if not wires:
                self.warnings.append(f"Page '{page_name}': No wire data found")

    def _validate_wire_rules(self, pages_data):
        """Validate wire type rules (twisted pairs, etc.)"""
        for page_name, page_data in pages_data.items():
            wires = page_data.get('wires', [])

            i = 0
            while i < len(wires):
                wire = wires[i]
                wire_type = wire.get('Type', '').upper()

                if wire_type in ['TWISTED', 'TW', 'SHIELDED TWISTED', 'ST']:
                    # Check if this is part of a twisted pair
                    if i + 1 >= len(wires):
                        self.errors.append(f"Page '{page_name}', wire '{wire.get('Signal name', '')}': "
                                           f"Twisted pair '{wire_type}' must have exactly 2 wires")
                        break

                    next_wire = wires[i + 1]
                    next_wire_type = next_wire.get('Type', '').upper()

                    if next_wire_type not in ['TWISTED', 'TW', 'SHIELDED TWISTED', 'ST']:
                        self.errors.append(f"Page '{page_name}', wire '{wire.get('Signal name', '')}': "
                                           f"Twisted pair must consist of 2 consecutive wires of the same type")

                    # Skip the next wire as it's part of the pair
                    i += 2
                else:
                    i += 1

    def _validate_connector_pins(self, pages_data):
        """Validate connector pin names and uniqueness (separate for left and right connectors)"""
        # Separate tracking for left and right connectors
        all_right_pins = {}  # Format: {connector_name: set(pin_names)}
        all_left_pins = {}  # Format: {connector_name: set(pin_names)}

        for page_name, page_data in pages_data.items():
            wires = page_data.get('wires', [])
            page_right_pins = {}
            page_left_pins = {}

            for wire in wires:
                # Validate right connector pins
                right_connector = wire.get('Right connector', '')
                if right_connector:
                    self._validate_pin_format(right_connector, page_name, wire.get('Signal name', ''), "right")
                    connector_name, pin_name = self._split_connector_pin(right_connector)
                    if connector_name and pin_name:
                        # Check page-level uniqueness for right connector
                        if connector_name not in page_right_pins:
                            page_right_pins[connector_name] = set()
                        if pin_name in page_right_pins[connector_name]:
                            self.errors.append(f"Page '{page_name}': Duplicate pin '{right_connector}' "
                                               f"in right connector '{connector_name}'")
                        page_right_pins[connector_name].add(pin_name)

                        # Check global uniqueness for right connector
                        if connector_name not in all_right_pins:
                            all_right_pins[connector_name] = set()
                        if pin_name in all_right_pins[connector_name]:
                            self.errors.append(f"Duplicate pin '{right_connector}' in right connector "
                                               f"'{connector_name}' across multiple pages")
                        all_right_pins[connector_name].add(pin_name)

                # Validate left connector pins
                left_connector = wire.get('Left connector', '')
                if left_connector:
                    self._validate_pin_format(left_connector, page_name, wire.get('Signal name', ''), "left")
                    connector_name, pin_name = self._split_connector_pin(left_connector)
                    if connector_name and pin_name:
                        # Check page-level uniqueness for left connector
                        if connector_name not in page_left_pins:
                            page_left_pins[connector_name] = set()
                        if pin_name in page_left_pins[connector_name]:
                            self.errors.append(f"Page '{page_name}': Duplicate pin '{left_connector}' "
                                               f"in left connector '{connector_name}'")
                        page_left_pins[connector_name].add(pin_name)

                        # Check global uniqueness for left connector
                        if connector_name not in all_left_pins:
                            all_left_pins[connector_name] = set()
                        if pin_name in all_left_pins[connector_name]:
                            self.errors.append(f"Duplicate pin '{left_connector}' in left connector "
                                               f"'{connector_name}' across multiple pages")
                        all_left_pins[connector_name].add(pin_name)

    def _validate_pin_format(self, pin_name, page_name, signal_name, side):
        """Validate pin name format"""
        if not pin_name:
            return

        if '/' not in pin_name:
            self.errors.append(f"Page '{page_name}', signal '{signal_name}': "
                               f"{side} connector pin '{pin_name}' must be in format 'CONNECTOR_NAME/PIN_NAME'")
            return

        parts = pin_name.split('/')
        if len(parts) != 2:
            self.errors.append(f"Page '{page_name}', signal '{signal_name}': "
                               f"{side} connector pin '{pin_name}' must be in format 'CONNECTOR_NAME/PIN_NAME'")
        elif not parts[0] or not parts[1]:
            self.errors.append(f"Page '{page_name}', signal '{signal_name}': "
                               f"{side} connector pin '{pin_name}' has empty connector or pin name")

    def _split_connector_pin(self, connector_pin):
        """Split connector/pin into separate parts"""
        if '/' not in connector_pin:
            return None, None
        parts = connector_pin.split('/')
        return parts[0].strip(), parts[1].strip()

    def _validate_signal_names(self, pages_data):
        """Validate signal name uniqueness"""
        all_signals = set()

        for page_name, page_data in pages_data.items():
            wires = page_data.get('wires', [])
            page_signals = set()

            for wire in wires:
                signal_name = wire.get('Signal name', '')
                if not signal_name or signal_name.upper() == 'SPACE':
                    continue

                if signal_name in page_signals:
                    self.errors.append(f"Page '{page_name}': Duplicate signal name '{signal_name}'")

                if signal_name in all_signals:
                    self.warnings.append(f"Signal name '{signal_name}' appears on multiple pages")

                page_signals.add(signal_name)
                all_signals.add(signal_name)

    def _validate_page_capacity(self, pages_data):
        """Validate that page doesn't exceed wire capacity"""
        # Maximum wires per page (adjust based on your A3 page layout)
        MAX_WIRES_PER_PAGE = 100

        for page_name, page_data in pages_data.items():
            wires = page_data.get('wires', [])
            wire_count = len([w for w in wires if w.get('Signal name', '').upper() != 'SPACE'])

            if wire_count > MAX_WIRES_PER_PAGE:
                self.errors.append(f"Page '{page_name}': Too many wires ({wire_count}). "
                                   f"Maximum allowed is {MAX_WIRES_PER_PAGE}")

    def _validate_wire_offsets(self, pages_data):
        """Validate wire offset rules"""
        for page_name, page_data in pages_data.items():
            wires = page_data.get('wires', [])

            for i, wire in enumerate(wires):
                right_offset = wire.get('Right wire offset', '')
                left_offset = wire.get('Left wire offset', '')

                # Validate offset format
                if right_offset and right_offset not in ['', '0']:
                    if not self._is_valid_offset(right_offset):
                        self.errors.append(f"Page '{page_name}', signal '{wire.get('Signal name', '')}': "
                                           f"Invalid right offset '{right_offset}'. Must be integer.")

                if left_offset and left_offset not in ['', '0']:
                    if not self._is_valid_offset(left_offset):
                        self.errors.append(f"Page '{page_name}', signal '{wire.get('Signal name', '')}': "
                                           f"Invalid left offset '{left_offset}'. Must be integer.")

    def _is_valid_offset(self, offset_str):
        """Check if offset string is valid integer"""
        try:
            int(offset_str)
            return True
        except ValueError:
            return False

    def get_validation_summary(self):
        """Get formatted validation summary"""
        summary = []

        if self.errors:
            summary.append("VALIDATION ERRORS:")
            for error in self.errors:
                summary.append(f"  ❌ {error}")

        if self.warnings:
            summary.append("VALIDATION WARNINGS:")
            for warning in self.warnings:
                summary.append(f"  ⚠️  {warning}")

        if not self.errors and not self.warnings:
            summary.append("✅ Validation passed successfully")

        return "\n".join(summary)
