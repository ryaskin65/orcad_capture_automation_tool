# RIGa&DeepSeek 21.12.2025

# wire_data.py
from typing import Dict, List, Tuple, Optional, Set
from dataclasses import dataclass


@dataclass
class WireData:
    """
    Data structure representing a single wire in cable documentation

    This class holds all information about a wire from the input Excel file
    """

    signal_name: str  # Signal identifier (e.g., "P11", "P12")
    left_connector: str  # Left connector/pin (format: "CONNECTOR/PIN")
    right_connector: str  # Right connector/pin (format: "CONNECTOR/PIN")
    left_in_out: str  # Signal direction on left side ("IN" or "OUT")
    wire_type: str  # Wire type (e.g., "", "TW", "ST")
    left_gauge: str  # Wire gauge on left side (e.g., "20", "22")
    color: str  # Wire color
    right_gauge: str  # Wire gauge on right side
    connect_left: str  # Connection to left wire (wire number as string)
    connect_right: str  # Connection to right wire (wire number as string)
    page_name: str = ""  # Page name containing this wire
    wire_num: int = 0  # Wire number (1-based) within page


class WireDataProcessor:
    """
    Processor for wire data operations including parsing and validation

    Handles:
    - Parsing Excel rows into WireData objects
    - Validating wire data according to cable documentation rules
    - Checking connector formats and uniqueness
    """

    def __init__(self, message_logger):
        self.message_logger = message_logger

    def parse_wire_data(
        self, row: tuple, column_mapping: Dict[str, int]
    ) -> Optional[WireData]:
        """
        Parse a single Excel row into a WireData object

        Args:
            row: Tuple of cell values from Excel row
            column_mapping: Dictionary mapping field names to column indices

        Returns:
            WireData object if valid, None if row should be skipped
        """
        # Initialize WireData with empty values
        wire_data = WireData(
            signal_name="",
            left_connector="",
            right_connector="",
            left_in_out="",
            wire_type="",
            left_gauge="",
            color="",
            right_gauge="",
            connect_left="",
            connect_right="",
        )

        # Fill data from row using column mapping
        for field_name, col_index in column_mapping.items():
            if col_index < len(row):
                value = row[col_index]
                if value is not None:
                    str_value = str(value).strip()
                    # Map Excel field name to WireData attribute
                    attribute_name = self._map_field_name(field_name)
                    setattr(wire_data, attribute_name, str_value)

        # Skip rows without signal name (empty rows or headers)
        if not wire_data.signal_name:
            return None

        return wire_data

    def _map_field_name(self, field_name: str) -> str:
        """
        Map Excel column header names to WireData attribute names

        Args:
            field_name: Excel column header

        Returns:
            Corresponding WireData attribute name
        """
        mapping = {
            "Signal name": "signal_name",
            "Left connector": "left_connector",
            "Right connector": "right_connector",
            "Left side IN/OUT": "left_in_out",
            "Type": "wire_type",
            "Left wire width, Gauge": "left_gauge",
            "Color": "color",
            "Right wire width, Gauge": "right_gauge",
            "Connect to left wire with number": "connect_left",
            "Connect to right wire with number": "connect_right",
        }
        return mapping.get(field_name, field_name.lower().replace(" ", "_"))

    def validate_wire_type_rules(
        self, page_name: str, wires: List[WireData]
    ) -> Tuple[List[str], List[str]]:
        """
        Validate wire type rules, especially for twisted pairs

        Rules:
        - Twisted pairs ("TW", "ST") must appear in consecutive pairs
        - A twisted pair type must be followed by another wire of the same type

        Args:
            page_name: Name of the page being validated
            wires: List of WireData objects on the page

        Returns:
            Tuple of (errors, warnings)
        """
        errors = []
        warnings = []

        i = 0
        while i < len(wires):
            wire = wires[i]
            wire_type = wire.wire_type.upper() if wire.wire_type else ""

            # Check if this is a twisted pair type
            if wire_type in ["TWISTED", "TW", "SHIELDED TWISTED", "ST"]:
                # Twisted pair must have exactly 2 wires
                if i + 1 >= len(wires):
                    errors.append(
                        f"Page '{page_name}', wire '{wire.signal_name}': "
                        f"Twisted pair '{wire_type}' must have exactly 2 wires"
                    )
                    break

                next_wire = wires[i + 1]
                next_wire_type = (
                    next_wire.wire_type.upper() if next_wire.wire_type else ""
                )

                # Next wire must also be a twisted pair
                if next_wire_type not in ["TWISTED", "TW", "SHIELDED TWISTED", "ST"]:
                    errors.append(
                        f"Page '{page_name}', wire '{wire.signal_name}': "
                        f"Twisted pair must consist of 2 consecutive wires of the same type"
                    )

                # Skip the second wire of the pair
                i += 2
            else:
                i += 1

        return errors, warnings

    def validate_connector_pins(
        self, page_name: str, wires: List[WireData]
    ) -> Tuple[List[str], List[str]]:
        """
        Validate connector pin names and ensure uniqueness within connectors

        Rules:
        1. Connector pins must be in format "CONNECTOR_NAME/PIN_NAME"
        2. Pin names must be unique within each connector

        Args:
            page_name: Name of the page being validated
            wires: List of WireData objects on the page

        Returns:
            Tuple of (errors, warnings)
        """
        errors = []
        warnings = []

        # Track pins for each connector on right and left sides
        page_right_pins: Dict[str, Set[str]] = {}  # connector_name -> set of pin_names
        page_left_pins: Dict[str, Set[str]] = {}  # connector_name -> set of pin_names

        for wire in wires:
            # Validate right connector pins
            right_connector = wire.right_connector
            if right_connector:
                # Check pin format
                pin_errors = self._validate_pin_format(
                    right_connector, page_name, wire.signal_name, "right"
                )
                errors.extend(pin_errors)

                # Extract connector and pin names
                connector_name, pin_name = self.split_connector_pin(right_connector)
                if connector_name and pin_name:
                    # Initialize connector set if needed
                    if connector_name not in page_right_pins:
                        page_right_pins[connector_name] = set()

                    # Check for duplicate pins
                    if pin_name in page_right_pins[connector_name]:
                        errors.append(
                            f"Page '{page_name}': Duplicate pin '{right_connector}' "
                            f"in right connector '{connector_name}'"
                        )

                    # Add pin to connector set
                    page_right_pins[connector_name].add(pin_name)

            # Validate left connector pins
            left_connector = wire.left_connector
            if left_connector:
                # Check pin format
                pin_errors = self._validate_pin_format(
                    left_connector, page_name, wire.signal_name, "left"
                )
                errors.extend(pin_errors)

                # Extract connector and pin names
                connector_name, pin_name = self.split_connector_pin(left_connector)
                if connector_name and pin_name:
                    # Initialize connector set if needed
                    if connector_name not in page_left_pins:
                        page_left_pins[connector_name] = set()

                    # Check for duplicate pins
                    if pin_name in page_left_pins[connector_name]:
                        errors.append(
                            f"Page '{page_name}': Duplicate pin '{left_connector}' "
                            f"in left connector '{connector_name}'"
                        )

                    # Add pin to connector set
                    page_left_pins[connector_name].add(pin_name)

        return errors, warnings

    def _validate_pin_format(
        self, pin_name: str, page_name: str, signal_name: str, side: str
    ) -> List[str]:
        """
        Validate pin name format

        Required format: "CONNECTOR_NAME/PIN_NAME"

        Args:
            pin_name: Full pin name to validate
            page_name: Name of page for error messages
            signal_name: Signal name for error messages
            side: "left" or "right" for error messages

        Returns:
            List of error messages
        """
        errors = []

        if not pin_name:
            return errors

        # Check for required slash separator
        if "/" not in pin_name:
            errors.append(
                f"Page '{page_name}', signal '{signal_name}': "
                f"{side} connector pin '{pin_name}' must be in format 'CONNECTOR_NAME/PIN_NAME'"
            )
            return errors

        # Split and validate parts
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

    @staticmethod
    def split_connector_pin(connector_pin: str) -> Tuple[Optional[str], Optional[str]]:
        """
        Split connector/pin string into connector name and pin name

        Args:
            connector_pin: String in format "CONNECTOR_NAME/PIN_NAME"

        Returns:
            Tuple of (connector_name, pin_name)
            Returns (None, None) if format is invalid
        """
        if not connector_pin or "/" not in connector_pin:
            return None, None

        # Split only on first slash (in case pin name contains slashes)
        parts = connector_pin.split("/", 1)
        connector_name = parts[0].strip()
        pin_name = parts[1].strip() if len(parts) > 1 else ""

        return connector_name, pin_name

    def validate_signal_names(
        self, page_name: str, wires: List[WireData]
    ) -> Tuple[List[str], List[str]]:
        """
        Validate signal name uniqueness

        Rules:
        1. Signal names must be unique within a page
        2. "SPACE" is treated specially and doesn't need to be unique

        Args:
            page_name: Name of the page being validated
            wires: List of WireData objects on the page

        Returns:
            Tuple of (errors, warnings)
        """
        errors = []
        warnings = []

        page_signals: Set[str] = set()

        for wire in wires:
            signal_name = wire.signal_name

            # Skip empty signals and "SPACE" (special case)
            if not signal_name or signal_name.upper() == "SPACE":
                continue

            # Check for duplicates
            if signal_name in page_signals:
                errors.append(
                    f"Page '{page_name}': Duplicate signal name '{signal_name}'"
                )

            # Add to tracking set
            page_signals.add(signal_name)

        return errors, warnings

    def find_wire_by_signal_name(
        self, wires: List[WireData], signal_name: str
    ) -> Optional[WireData]:
        """
        Find a wire by its signal name

        Args:
            wires: List of WireData objects to search
            signal_name: Signal name to find

        Returns:
            WireData object if found, None otherwise
        """
        for wire in wires:
            if wire.signal_name == signal_name:
                return wire
        return None

    def get_wire_by_number(
        self, wires: List[WireData], wire_num: int
    ) -> Optional[WireData]:
        """
        Get wire by its position number (1-based)

        Args:
            wires: List of WireData objects
            wire_num: Wire number (1-based)

        Returns:
            WireData object if found, None if index out of range
        """
        if 1 <= wire_num <= len(wires):
            return wires[wire_num - 1]
        return None

    def extract_connector_names(self, wires: List[WireData], side: str) -> Set[str]:
        """
        Extract unique connector names from wires for a given side

        Args:
            wires: List of WireData objects
            side: "left" or "right"

        Returns:
            Set of unique connector names
        """
        connectors = set()

        for wire in wires:
            connector_pin = (
                wire.left_connector if side == "left" else wire.right_connector
            )
            if connector_pin:
                connector_name, _ = self.split_connector_pin(connector_pin)
                if connector_name:
                    connectors.add(connector_name)

        return connectors

    def validate_group_count_rules(
        self, page_name: str, wires: List[WireData]
    ) -> Tuple[List[str], List[str]]:
        """
        Basic validation for group count rules (warning only)

        Full validation happens during wire calculation in OffsetCalculator

        Returns: (errors, warnings)
        """
        errors = []
        warnings = []

        # Count unique splices per side as warning only
        left_splices = set()
        right_splices = set()

        for i, wire in enumerate(wires):
            wire_num = i + 1

            if wire.connect_left and wire.connect_left.strip():
                try:
                    target = int(wire.connect_left.strip())
                    if 1 <= target <= len(wires):
                        left_splices.add(target)
                except ValueError:
                    pass

            if wire.connect_right and wire.connect_right.strip():
                try:
                    target = int(wire.connect_right.strip())
                    if 1 <= target <= len(wires):
                        right_splices.add(target)
                except ValueError:
                    pass

        # Warning for many splices (might need careful Y-range planning)
        if len(left_splices) > 4:
            warnings.append(
                f"Page '{page_name}': Found {len(left_splices)} splices on left side. "
                f"May be difficult to fit into 2 X-offset groups without Y-range intersections."
            )

        if len(right_splices) > 4:
            warnings.append(
                f"Page '{page_name}': Found {len(right_splices)} splices on right side. "
                f"May be difficult to fit into 2 X-offset groups without Y-range intersections."
            )

        return errors, warnings

    def validate_connection_consistency(
        self, page_name: str, wires: List[WireData]
    ) -> Tuple[List[str], List[str]]:
        """
        Validate that connections are consistent and don't create contradictions

        Rules:
        1. If wire A connects to wire B on left side, wire B should be a valid target
        2. Wire cannot connect to itself
        3. Connections should not create impossible Y-offset requirements
        4. No connection chains longer than 2 (A→B→C is prohibited)

        Returns: (errors, warnings)
        """
        errors = []
        warnings = []

        # Build connection maps
        left_connections = {}
        right_connections = {}

        for i, wire in enumerate(wires):
            wire_num = i + 1

            # Parse left connections
            if wire.connect_left and wire.connect_left.strip():
                try:
                    target = int(wire.connect_left.strip())
                    if 1 <= target <= len(wires):
                        left_connections[wire_num] = target
                    else:
                        errors.append(
                            f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                            f"Invalid left connection target {target}. "
                            f"Valid wire numbers are 1 to {len(wires)}."
                        )
                except ValueError:
                    errors.append(
                        f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                        f"Invalid left connection value '{wire.connect_left}'. "
                        f"Must be a wire number."
                    )

            # Parse right connections
            if wire.connect_right and wire.connect_right.strip():
                try:
                    target = int(wire.connect_right.strip())
                    if 1 <= target <= len(wires):
                        right_connections[wire_num] = target
                    else:
                        errors.append(
                            f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                            f"Invalid right connection target {target}. "
                            f"Valid wire numbers are 1 to {len(wires)}."
                        )
                except ValueError:
                    errors.append(
                        f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                        f"Invalid right connection value '{wire.connect_right}'. "
                        f"Must be a wire number."
                    )

        # Check for self-connections
        for wire_num, target in left_connections.items():
            if wire_num == target:
                wire = wires[wire_num - 1]
                errors.append(
                    f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                    f"Cannot connect to itself on left side."
                )

        for wire_num, target in right_connections.items():
            if wire_num == target:
                wire = wires[wire_num - 1]
                errors.append(
                    f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                    f"Cannot connect to itself on right side."
                )

        # Check for cycles (A→B→A is impossible)
        left_adj = {i: [] for i in range(1, len(wires) + 1)}
        right_adj = {i: [] for i in range(1, len(wires) + 1)}

        for source, target in left_connections.items():
            left_adj[source].append(target)

        for source, target in right_connections.items():
            right_adj[source].append(target)

        def has_cycle(adj, start, visited, rec_stack):
            visited[start] = True
            rec_stack[start] = True

            for neighbor in adj[start]:
                if not visited.get(neighbor, False):
                    if has_cycle(adj, neighbor, visited, rec_stack):
                        return True
                elif rec_stack.get(neighbor, False):
                    return True

            rec_stack[start] = False
            return False

        # Check left side for cycles
        left_visited = {}
        left_rec_stack = {}
        for wire_num in range(1, len(wires) + 1):
            if not left_visited.get(wire_num, False):
                if has_cycle(left_adj, wire_num, left_visited, left_rec_stack):
                    errors.append(
                        f"Page '{page_name}': Cycle detected in left side connections. "
                        f"This creates impossible Y-offset requirements (e.g., A→B→A)."
                    )
                    break

        # Check right side for cycles
        right_visited = {}
        right_rec_stack = {}
        for wire_num in range(1, len(wires) + 1):
            if not right_visited.get(wire_num, False):
                if has_cycle(right_adj, wire_num, right_visited, right_rec_stack):
                    errors.append(
                        f"Page '{page_name}': Cycle detected in right side connections. "
                        f"This creates impossible Y-offset requirements (e.g., A→B→A)."
                    )
                    break

        # Check for connection chains longer than 2 (A→B→C is prohibited)
        left_chains = self._find_connection_chains(left_connections)
        right_chains = self._find_connection_chains(right_connections)

        for chain in left_chains:
            if len(chain) > 2:  # ERROR: Chain of 3 or more wires is prohibited
                chain_signals = [wires[w - 1].signal_name for w in chain]
                errors.append(
                    f"Page '{page_name}': Invalid left connection chain: {' → '.join(chain_signals)}. "
                    f"Maximum chain length is 2 wires (e.g., A→B). "
                    f"Chain of {len(chain)} wires is not allowed."
                )
            elif len(chain) == 2:  # WARNING: Chain of 2 wires (A→B)
                chain_signals = [wires[w - 1].signal_name for w in chain]
                warnings.append(
                    f"Page '{page_name}': Left connection chain detected: {' → '.join(chain_signals)}. "
                    f"Splice wire {chain[1]} will have offset = 0."
                )

        for chain in right_chains:
            if len(chain) > 2:  # ERROR: Chain of 3 or more wires is prohibited
                chain_signals = [wires[w - 1].signal_name for w in chain]
                errors.append(
                    f"Page '{page_name}': Invalid right connection chain: {' → '.join(chain_signals)}. "
                    f"Maximum chain length is 2 wires (e.g., A→B). "
                    f"Chain of {len(chain)} wires is not allowed."
                )
            elif len(chain) == 2:  # WARNING: Chain of 2 wires (A→B)
                chain_signals = [wires[w - 1].signal_name for w in chain]
                warnings.append(
                    f"Page '{page_name}': Right connection chain detected: {' → '.join(chain_signals)}. "
                    f"Splice wire {chain[1]} will have offset = 0."
                )

        # Additional check: if wire connects to another wire that also has connection
        # This is already covered by chain detection above, but specific message:
        for wire_num, target in left_connections.items():
            if target in left_connections:
                # This means wire_num→target and target→something
                # Which creates chain of at least 3: wire_num→target→something
                source_wire = wires[wire_num - 1]
                target_wire = wires[target - 1]
                next_target = left_connections[target]
                next_wire = wires[next_target - 1]

                errors.append(
                    f"Page '{page_name}', wire {wire_num} ('{source_wire.signal_name}'): "
                    f"Connects to wire {target} which itself connects to wire {next_target}. "
                    f"This creates prohibited chain: {source_wire.signal_name}→{target_wire.signal_name}→{next_wire.signal_name}. "
                    f"Maximum allowed is direct connection (A→B)."
                )

        for wire_num, target in right_connections.items():
            if target in right_connections:
                source_wire = wires[wire_num - 1]
                target_wire = wires[target - 1]
                next_target = right_connections[target]
                next_wire = wires[next_target - 1]

                errors.append(
                    f"Page '{page_name}', wire {wire_num} ('{source_wire.signal_name}'): "
                    f"Connects to wire {target} which itself connects to wire {next_target}. "
                    f"This creates prohibited chain: {source_wire.signal_name}→{target_wire.signal_name}→{next_wire.signal_name}. "
                    f"Maximum allowed is direct connection (A→B)."
                )

        return errors, warnings

    def _find_connection_chains(self, connections: Dict[int, int]) -> List[List[int]]:
        """
        Find all connection chains in the connection graph

        Returns: List of chains, e.g., [[1,2,3], [4,5]] for 1→2→3 and 4→5
        """
        chains = []
        visited = set()

        for start in connections.keys():
            if start not in visited:
                chain = []
                current = start

                while current and current not in visited:
                    visited.add(current)
                    chain.append(current)
                    current = connections.get(current)

                if len(chain) > 1:
                    chains.append(chain)

        return chains

    def validate_splice_rules(
        self, page_name: str, wires: List[WireData]
    ) -> Tuple[List[str], List[str]]:
        """
        Validate that splices are correctly defined

        Rules:
        1. Splice wire must be a target of at least one connection
        2. Splice wire should not have outgoing connections (already checked elsewhere)
        3. Every connection should point to a valid wire

        Returns: (errors, warnings)
        """
        errors = []
        warnings = []

        # Build connection maps
        left_targets = set()
        right_targets = set()
        left_sources = set()
        right_sources = set()

        for i, wire in enumerate(wires):
            wire_num = i + 1

            if wire.connect_left and wire.connect_left.strip():
                try:
                    target = int(wire.connect_left.strip())
                    if 1 <= target <= len(wires):
                        left_sources.add(wire_num)
                        left_targets.add(target)
                    else:
                        errors.append(
                            f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                            f"Left connection points to invalid wire {target}"
                        )
                except ValueError:
                    pass

            if wire.connect_right and wire.connect_right.strip():
                try:
                    target = int(wire.connect_right.strip())
                    if 1 <= target <= len(wires):
                        right_sources.add(wire_num)
                        right_targets.add(target)
                    else:
                        errors.append(
                            f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                            f"Right connection points to invalid wire {target}"
                        )
                except ValueError:
                    pass

        # Check for wires that are targets but also sources
        left_splice_sources = left_targets.intersection(left_sources)
        right_splice_sources = right_targets.intersection(right_sources)

        for wire_num in left_splice_sources:
            wire = wires[wire_num - 1]
            warnings.append(
                f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                f"Is both target and source of left connections. "
                f"This may create offset conflicts."
            )

        for wire_num in right_splice_sources:
            wire = wires[wire_num - 1]
            warnings.append(
                f"Page '{page_name}', wire {wire_num} ('{wire.signal_name}'): "
                f"Is both target and source of right connections. "
                f"This may create offset conflicts."
            )

        return errors, warnings
