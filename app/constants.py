# RIGa&AI 2026 - shared constants
"""Centralized constants to avoid magic strings scattered across modules."""

# --- Keyboard layout -------------------------------------------------------
ENGLISH_LAYOUT_ID = 0x0409

# --- OrCAD window classes --------------------------------------------------
ORCAD_WINDOW_CLASS = "OrCaptureFrame"
ORCAD_COMMAND_WINDOW_CLASS = "Edit"

# --- Script execution / log monitoring ------------------------------------
LOG_FILENAME = "script_safe.log"
RUN_SCRIPT_FILENAME = "run_script.tcl"

# Completion marker written by the TCL scripts at the end of a run.
#
# IMPORTANT: this is a contract shared with the TCL scripts in scripts/.
# The scripts emit this exact string (see e.g. `SafeLog "Script done!"` in
# cable.tcl). Changing the value here REQUIRES updating every TCL script that
# emits it, otherwise log monitoring will time out. Do not change one side
# alone.
SCRIPT_DONE_MARKER = "Script done!"
EXECUTION_TIME_PREFIX = "EXECUTION_TIME:"

# Seconds without log-file growth before a run is considered hung.
# Raise this for very large pages where OrCAD may pause between log writes.
CHANGE_LOG_TIMEOUT = 4

# --- Cable data directives -------------------------------------------------
PAGE_DIRECTIVE = "PAGE"
ALL_PAGES = "all"
