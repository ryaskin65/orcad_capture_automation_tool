# OrCAD Capture Automation Tool

Python GUI with TCL scripts to automate routine tasks in OrCAD Capture
schematics: text search/replace, connector (off-page) direction changes, and
automatic cable drawing from an Excel table. Scripts run inside the OrCAD
command window, driven from the Python application.

> **Platform:** Windows only. The tool controls OrCAD through Win32 APIs and
> simulated keyboard/mouse input, so it does not run on Linux or macOS.

## Features

- Search and replace text in schematics
- Change connector (off-page) directions (input/output)
- Draw cables automatically from an Excel table
- Copy coordinates / text from selected objects
- Run TCL scripts via the Python GUI

## Project structure

```
orcad_capture_automation_tool/
├── app/                  # Python application
│   ├── cable_automation.py        # Entry point (MainApp, tabs)
│   ├── cable_automation_tab.py     # Cable drawing tab
│   ├── find_and_replace_tab.py     # Text search/replace tab
│   ├── offpage_tab.py              # Connectors & ports tab
│   ├── copy_xy_text_tab.py         # Copy X, Y, text tab
│   ├── copy_text_tab.py            # Copy text tab
│   ├── data_converter.py           # Input → output data conversion + validation
│   ├── wire_data.py                # WireData model + validation rules
│   ├── offset_calculator.py        # Y/X offset and group calculation
│   ├── orcad_canvas.py             # A3 boundary model / placement checks
│   ├── offpage_analyzer.py         # Off-page analysis report
│   ├── excel_utils.py              # Excel/CSV helpers
│   ├── screen_handler.py           # OrCAD window + keyboard layout handling
│   ├── orcad_script_runner.py      # Script execution + log monitoring
│   ├── layout_switcher.py          # English keyboard layout helper / launcher
│   └── message_logger.py           # In-app log widget
├── scripts/              # TCL scripts + TCL_CABLE.OLB library
├── data/                 # Generated CSV / report files
├── docs/                 # User guide
├── tests/                # Unit tests
├── requirements.txt
└── README.md
```

The Python code in `app/` resolves the `scripts/` and `data/` folders relative
to itself, so this layout must be preserved.

## Requirements

- Windows with OrCAD Capture (TCL command window support)
- Python 3.10+
- `TCL_CABLE.OLB` library present in `scripts/`
- Python packages listed in `requirements.txt`

## Installation

```bash
git clone https://github.com/ryaskin65/orcad_capture_automation_tool.git
cd orcad_capture_automation_tool

python -m venv .venv
.venv\Scripts\activate        # Windows

pip install -r requirements.txt
```

## Running

```bash
python app/cable_automation.py
```

The application requires an **English keyboard layout** to send commands
reliably to OrCAD. On start it checks the active layout and, if needed,
attempts to switch and asks you to restart.

## Usage outline

1. Prepare the cable data in Excel (see `docs/` for the column format).
2. In the **Cable Automation** tab, click *Load from Excel*.
3. Click *Run script* — the data is validated, converted, written to
   `data/cable.csv`, and the TCL script draws the schematic in OrCAD.

The active OrCAD page must be A3 (420 × 297 mm), in millimetres, and empty
before drawing.

## Running the tests

Pure validation logic has no GUI/OrCAD dependencies and runs anywhere:

```bash
pip install pytest
pytest tests/test_wire_validation.py
```

Or with the standard library:

```bash
python -m unittest discover -s tests
```

Tests that import the GUI layer require `tkinter` (bundled with the standard
Windows Python installer) and are skipped automatically where it is absent.

## License

MIT — see [LICENSE](LICENSE).
