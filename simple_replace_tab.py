import tkinter as tk
from tkinter import ttk
import os
import sys
from screen_handler import ScreenHandler

script_name = 'simple_replace.tcl'
script_change_direction_offpage_name = 'change_dir_offpage.tcl'

class SimpleReplaceTab:
    def __init__(self, notebook, message_logger):
        self.message_logger = message_logger
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler with MessageLogger
        self.screen_handler = ScreenHandler(self.message_logger)

        # Create a grid layout with 3 columns: left for fields, right for radiobuttons
        self.frame.columnconfigure(0, weight=0)
        self.frame.columnconfigure(1, weight=0)
        self.frame.columnconfigure(2, weight=0)

        # Find and Replace fields (left side)
        ttk.Label(self.frame, text="Find:").grid(row=0, column=0, padx=5, pady=5, sticky="w")
        self.find_entry = ttk.Entry(self.frame, width=50)
        self.find_entry.grid(row=0, column=1, padx=5, pady=5, sticky="w")

        ttk.Label(self.frame, text="Replace:").grid(row=1, column=0, padx=5, pady=5, sticky="w")
        self.replace_entry = ttk.Entry(self.frame, width=50)
        self.replace_entry.grid(row=1, column=1, padx=5, pady=5, sticky="w")

        # Replace button (below fields)
        self.replace_button = ttk.Button(self.frame, text="Run script", command=self.replace)
        self.replace_button.grid(row=3, column=2, padx=10, pady=5, sticky="ew")

        # Radiobuttons for scope (right side)
        self.scope_var = tk.StringVar(value="selected")  # Default to Selected Objects
        ttk.Radiobutton(self.frame, text="Selected Objects",
                        variable=self.scope_var,
                        value="selected",
                        state="disabled").grid(row=0, column=2, padx=10, pady=5, sticky="w")
        ttk.Radiobutton(self.frame,
                        text="Current Page",
                        variable=self.scope_var,
                        value="page",
                        state="disabled").grid(row=1, column=2, padx=10, pady=5, sticky="w")
        ttk.Radiobutton(self.frame,
                        text="All Pages",
                        variable=self.scope_var,
                        value="all",
                        state="disabled").grid(row=2, column=2, padx=10, pady=5, sticky="w")

        # Change direction Offpage button
        ttk.Label(self.frame, text="Change direction of Offpages").grid(row=7, column=0, padx=5, pady=5, sticky="w")
        self.change_dir_offpage_button = ttk.Button(self.frame, text="Run script", command=self.change_dir_offpage)
        self.change_dir_offpage_button.grid(row=8, column=0, padx=10, pady=5, sticky="ew")

        self.frame.grid_rowconfigure(0, weight=0)
        self.frame.grid_rowconfigure(1, weight=0)
        self.frame.grid_rowconfigure(2, weight=0)

    def change_dir_offpage(self):
        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()
        script_path = os.path.join(app_dir, script_change_direction_offpage_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        # Execute the script in OrCAD
        self.screen_handler.execute_in_orcad(script_path, self.message_logger)

    def replace(self):
        """Handle replace action."""
        find_text = self.find_entry.get()
        replace_text = self.replace_entry.get()
        scope = self.scope_var.get()
        scope_text = {
            "selected": "Selected Objects",
            "current": "Current Page",
            "all": "All Pages"
        }.get(scope, "no scope selected")

        if not find_text:
            self.message_logger.log_message('ERROR', "Error: Find text cannot be empty.")
            return

        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()
        script_path = os.path.join(app_dir, script_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        try:
            # Read or create the script file
            with open(script_path, "r") as f:
                lines = f.readlines()

            # Prepare the new replace command
            # new_line = f'replaceSelectedTexts "{find_text}" "{replace_text}" "{self.scope_var.get()}" \n'
            new_line = f'replaceSelectedTexts "{find_text}" "{replace_text}" \n'

            # Replace or append the last line
            if lines and lines[-1].strip().startswith("replaceSelectedTexts"):
                lines[-1] = new_line
            else:
                lines.append(new_line)

            # Save the updated script
            with open(script_path, "w") as f:
                f.writelines(lines)

            # Execute the script in OrCAD
            self.screen_handler.execute_in_orcad(script_path, self.message_logger)

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Error updating script: {str(e)}")
