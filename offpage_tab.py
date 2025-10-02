import tkinter as tk
from tkinter import ttk, filedialog
import os
import sys
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils

script_name_copy = 'copy_offpage.tcl'
script_name_replace = 'replace_offpage.tcl'
file_csv = 'offpage.csv'

class OffPageTab:
    def __init__(self, notebook, message_logger):
        """Initialize TableTab with notebook and message variable."""
        self.message_logger = message_logger
        self.excel_utils = ExcelUtils(message_logger)
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler
        self.screen_handler = ScreenHandler(self.message_logger)

        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_columnconfigure(1, weight=0, minsize=50)
        self.frame.grid_rowconfigure(0, weight=1)
        self.frame.grid_rowconfigure(1, weight=0)

        # Treeview for table
        self.tree = ttk.Treeview(self.frame, columns=("A", "B", "C"), show="headings")
        self.tree.heading("A", text="A")
        self.tree.heading("B", text="B")
        self.tree.heading("C", text="С")
        self.tree.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        radio_frame = ttk.Frame(self.frame)
        radio_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")

        # Radiobuttons for scope (right side)
        self.scope_var = tk.StringVar(value="page")  # Default to Selected Objects
        ttk.Radiobutton(radio_frame, text="Selected Objects", variable=self.scope_var,
                        value="selected", state="disabled").pack(anchor="w", pady=5)
        ttk.Radiobutton(radio_frame, text="Current Page", variable=self.scope_var,
                        value="page", state="disabled").pack(anchor="w", pady=5)
        ttk.Radiobutton(radio_frame, text="All Pages", variable=self.scope_var,
                        value="all", state="disabled").pack(anchor="w", pady=5)
        ttk.Button(radio_frame, text="Edit in Excel",
                   command=self.edit_in_excel).pack(anchor="e", pady=(20, 5), fill='x')
        ttk.Button(radio_frame, text="Load from Excel",
                   command=self.load_from_excel).pack(anchor="e", pady=(20, 5), fill='x')
        self.scope2_var = tk.StringVar(value="copy")
        ttk.Radiobutton(radio_frame, text="Copy OffPage", variable=self.scope2_var,
                        value="copy", state="enabled").pack(anchor="w", pady=5)
        ttk.Radiobutton(radio_frame, text="Replace OffPage", variable=self.scope2_var,
                        value="replace", state="enabled").pack(anchor="w", pady=5)
        ttk.Button(radio_frame, text="Run script", command=self.run_script).pack(anchor="e", pady=(20, 5), fill='x')

    def run_script(self):
        """Handle run script action."""
        self.load_from_excel()
        scope = self.scope_var.get()
        scope_text = {
            "selected": "Selected Objects",
            "page": "Current Page",
            "all": "All Pages"
        }.get(scope, "no scope selected")
        scope_script = self.scope2_var.get()

        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()

        if scope_script == 'copy':
            script_path = os.path.join(app_dir, script_name_copy)
        elif scope_script == 'replace':
            script_path = os.path.join(app_dir, script_name_replace)
        else:
            self.message_logger.log_message('ERROR', "Not selected script file!")
            return

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        csv_path = os.path.join(app_dir, file_csv)

        def make_script(name_function, delay=0):
            try:
                # Read or create the script file
                with open(script_path, "r") as f:
                    lines = f.readlines()

                # Prepare the new replace command
                new_line = name_function + ' ' + csv_path + '\n'
                new_line = new_line.replace('\\', '/')

                # Replace or append the last line
                if lines and lines[-1].strip().startswith(name_function):
                    lines[-1] = new_line
                else:
                    lines.append(new_line)

                # Save the updated script
                with open(script_path, "w") as f:
                    f.writelines(lines)

                # Execute the script in OrCAD
                self.screen_handler.execute_in_orcad(script_path, self.message_logger, delay)

                # self.message_logger.log_message('SUCCESS',
                #                                 f"Updated {script_path} "
                #                                 f"with '{file_csv}' in {scope_text}")

            except Exception as e:
                self.message_logger.log_message('ERROR', f"Error updating script: {str(e)}")

        if scope_script == 'copy':
            make_script("exportActivePageOffPages")
        elif scope_script == 'replace':
            make_script("replaceOffPageNamesByCoordinates", 2)

    def edit_in_excel(self):
        """Open CSV file directly in Microsoft Excel.
        Checks if file is already open before attempting to open it.
        Creates the file if it doesn't exist."""
        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()
        csv_path = os.path.join(app_dir, file_csv)

        try:
            # Create empty CSV file if it doesn't exist
            if not os.path.exists(csv_path):
                with open(csv_path, 'w') as f:
                    f.write("")  # Create empty file
                self.message_logger.log_message('SUCCESS', f"Created new CSV file: {csv_path}")

            # Check if file is already open (locked)
            if self._is_file_locked(csv_path):
                self.message_logger.log_message('ERROR', f"File is already open: {csv_path}")
                return

            # Open the CSV file in Excel
            os.startfile(csv_path)
            self.message_logger.log_message('SUCCESS', f"Opened CSV file in Excel: {csv_path}")

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Failed to open CSV file: {str(e)}")

    def _is_file_locked(self, filepath):
        """Check if file is locked by attempting to open it in exclusive mode"""
        try:
            if os.path.exists(filepath):
                with open(filepath, 'a', encoding='utf-8') as f:
                    pass
            return False
        except IOError:
            return True

    def load_from_excel(self):
        """Load data from configured Excel file into treeview"""
        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()
        csv_path = os.path.join(app_dir, file_csv)

        if not os.path.exists(csv_path):
            self.message_logger.log_message('ERROR', "CSV file does not exist")
            return

        success = self.excel_utils.load_csv_to_treeview(
            csv_path=csv_path,
            tree=self.tree
        )

        if success:
            self.message_logger.log_message('SUCCESS', f"Loaded data from {csv_path}")
