import tkinter as tk
from tkinter import ttk, filedialog
import os
import sys
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils

script_copy_off = 'copy_offpage.tcl'
script_repl_off = 'replace_offpage.tcl'
script_change_dir_off = 'change_dir_offpage.tcl'
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
        ttk.Button(radio_frame, text="Copy X, Y, names", command=self.copy_offpage).pack(anchor="e", pady=(20, 5), fill='x')
        ttk.Button(radio_frame, text="Replace names", command=self.replace_offpage).pack(anchor="e", pady=(20, 5), fill='x')
        ttk.Button(radio_frame, text="Change direction", command=self.change_direction).pack(anchor="e", pady=(20, 5), fill='x')

    def get_scripts_dir(self):
        """Get path to scripts directory"""
        if getattr(sys, 'frozen', False):
            app_dir = os.path.dirname(sys.executable)
        else:
            app_dir = os.path.dirname(os.path.abspath(__file__))

        if getattr(sys, 'frozen', False):
            # For executable: scripts folder is at same level as executable
            scripts_dir = os.path.join(app_dir, "scripts")
        else:
            # For development: scripts folder is at same level as app folder
            scripts_dir = os.path.join(os.path.dirname(app_dir), "scripts")

        return scripts_dir

    def make_script(self, script_path, csv_path, name_function, delay=0):
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

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Error updating script: {str(e)}")

    def copy_offpage(self):
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_copy_off)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)
        self.make_script(script_path, csv_path, "exportActivePageOffPages")

    def replace_offpage(self):
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_repl_off)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)
        self.make_script(script_path, csv_path, "replaceOffPageNamesByCoordinates", 2)

    def change_direction(self):
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_change_dir_off)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        # Execute the script in OrCAD
        self.screen_handler.execute_in_orcad(script_path, self.message_logger)

    def edit_in_excel(self):
        """Open CSV file directly in Microsoft Excel.
        Checks if file is already open before attempting to open it.
        Creates the file if it doesn't exist."""
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)

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
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)

        if not os.path.exists(csv_path):
            self.message_logger.log_message('ERROR', "CSV file does not exist")
            return

        success = self.excel_utils.load_csv_to_treeview(
            csv_path=csv_path,
            tree=self.tree
        )

        if success:
            self.message_logger.log_message('SUCCESS', f"Loaded data from {csv_path}")
