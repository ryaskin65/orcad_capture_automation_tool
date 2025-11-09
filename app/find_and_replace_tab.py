# RIGa&DeepSeek 26.10.2025
import tkinter as tk
from tkinter import ttk
import os
import sys
from screen_handler import ScreenHandler
from orcad_script_runner import OrcadScriptRunner

script_name = "find_and_replace.tcl"


class FindAndReplaceTab:
    def __init__(self, notebook, message_logger):
        self.message_logger = message_logger
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler and ScriptRunner
        self.screen_handler = ScreenHandler(self.message_logger)
        self.script_runner = OrcadScriptRunner(
            self.screen_handler, self.message_logger, self.get_scripts_dir()
        )

        # Create a grid layout with 3 columns: left for fields, right for radiobuttons
        self.frame.columnconfigure(0, weight=0)
        self.frame.columnconfigure(1, weight=0)
        self.frame.columnconfigure(2, weight=0)

        # Find and Replace fields (left side)
        ttk.Label(self.frame, text="Find:").grid(
            row=0, column=0, padx=5, pady=5, sticky="w"
        )
        self.find_entry = ttk.Entry(self.frame, width=50)
        self.find_entry.grid(row=0, column=1, padx=5, pady=5, sticky="w")

        ttk.Label(self.frame, text="Replace:").grid(
            row=1, column=0, padx=5, pady=5, sticky="w"
        )
        self.replace_entry = ttk.Entry(self.frame, width=50)
        self.replace_entry.grid(row=1, column=1, padx=5, pady=5, sticky="w")

        # Replace button (below fields)
        self.replace_button = ttk.Button(
            self.frame, text="Find and replace", command=self.replace
        )
        self.replace_button.grid(row=3, column=2, padx=10, pady=5, sticky="ew")

        # Radiobuttons for scope (right side)
        self.scope_var = tk.StringVar(value="selected")  # Default to Selected Objects
        ttk.Radiobutton(
            self.frame,
            text="Selected Objects",
            variable=self.scope_var,
            value="selected",
            state="disabled",
        ).grid(row=0, column=2, padx=10, pady=5, sticky="w")
        ttk.Radiobutton(
            self.frame,
            text="Current Page",
            variable=self.scope_var,
            value="page",
            state="disabled",
        ).grid(row=1, column=2, padx=10, pady=5, sticky="w")
        ttk.Radiobutton(
            self.frame,
            text="All Pages",
            variable=self.scope_var,
            value="all",
            state="disabled",
        ).grid(row=2, column=2, padx=10, pady=5, sticky="w")

        self.frame.grid_rowconfigure(0, weight=0)
        self.frame.grid_rowconfigure(1, weight=0)
        self.frame.grid_rowconfigure(2, weight=0)

    def get_scripts_dir(self):
        """Get path to scripts directory"""
        if getattr(sys, "frozen", False):
            app_dir = os.path.dirname(sys.executable)
        else:
            app_dir = os.path.dirname(os.path.abspath(__file__))

        if getattr(sys, "frozen", False):
            # For executable: scripts folder is at same level as executable
            scripts_dir = os.path.join(app_dir, "scripts")
        else:
            # For development: scripts folder is at same level as app folder
            scripts_dir = os.path.join(os.path.dirname(app_dir), "scripts")

        return scripts_dir

    def replace(self):
        """Handle replace action."""
        find_text = self.find_entry.get()
        replace_text = self.replace_entry.get()
        scope = self.scope_var.get()

        if not find_text:
            self.message_logger.log_message(
                "ERROR", "Error: Find text cannot be empty."
            )
            return

        # Create dictionary of global variables
        glob_var = [
            ["::find_text", find_text],
            ["::replace_text", replace_text],
            ["::scope", scope],
        ]

        def execution_callback(result):
            self.replace_button.config(state="normal")
            # Don't log error here - it's already logged in screen_handler or script_runner
            # Just update button state

        # Update button state
        self.replace_button.config(state="disabled")

        # Execute the script
        success = self.script_runner.execute_script(
            script_name, glob_var, execution_callback
        )

        if not success:
            self.replace_button.config(state="normal")
