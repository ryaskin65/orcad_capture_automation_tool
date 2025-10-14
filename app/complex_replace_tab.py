import tkinter as tk
from tkinter import ttk, filedialog
import os
import sys
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils

script_name = 'complex_replace.tcl'
file_xlsx = 'complex_replace.xlsx'
file_csv = 'complex_replace.csv'

class ComplexReplaceTab:
    def __init__(self, notebook, message_logger):
        """Initialize TableTab with notebook and message variable."""
        self.message_logger = message_logger
        self.excel_utils = ExcelUtils(message_logger)
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler
        self.screen_handler = ScreenHandler(self.message_logger)

        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_columnconfigure(1, weight=0, minsize=150)
        self.frame.grid_rowconfigure(0, weight=1)
        self.frame.grid_rowconfigure(1, weight=0)

        # Treeview for table
        self.tree = ttk.Treeview(self.frame, columns=("A", "B"), show="headings")
        self.tree.heading("A", text="A")
        self.tree.heading("B", text="B")
        self.tree.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        radio_frame = ttk.Frame(self.frame)
        radio_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")

        # Radiobuttons for scope (right side)
        self.scope_var = tk.StringVar(value="selected")  # Default to Selected Objects
        ttk.Radiobutton(radio_frame,  text="Selected Objects",  variable=self.scope_var,
                        value="selected",  state="disabled").pack(anchor="w", pady=5)
        ttk.Radiobutton(radio_frame, text="Current Page", variable=self.scope_var,
                        value="current", state="disabled").pack(anchor="w", pady=5)
        ttk.Radiobutton(radio_frame,  text="All Pages", variable=self.scope_var,
                        value="all", state="disabled").pack(anchor="w", pady=5)
        ttk.Button(radio_frame, text="Edit in Excel",
                   command=self.edit_in_excel).pack(anchor="e", pady=(20, 5), fill='x')
        ttk.Button(radio_frame, text="Load from Excel",
                   command=self.load_from_excel).pack(anchor="e", pady=(20, 5), fill='x')
        ttk.Button(radio_frame, text="Run script",
                   command=self.replace).pack(anchor="e", pady=(20, 5), fill='x')

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

    def replace(self):
        """Handle replace action for selected row, similar to FindReplaceTab."""
        # values = self.tree.item(selected[0])["values"]
        scope = self.scope_var.get()
        scope_text = {
            "selected": "Selected Objects",
            "current": "Current Page",
            "all": "All Pages"
        }.get(scope, "no scope selected")

        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        xlsx_path = os.path.join(csv_dir, file_xlsx)
        csv_path = os.path.join(csv_dir, file_csv)

        if not os.path.exists(xlsx_path):
            self.message_logger.log_message('ERROR', f'File "{xlsx_path}" not found!')
            return
        else:
            self.excel_utils.excel_to_csv_msdos(file_xlsx, csv_path)

        if not os.path.exists(csv_path):
            self.message_logger.log_message('ERROR', f'File "{csv_path}" not found!')
            return

        try:
            # Read or create the script file
            with open(script_path, "r") as f:
                lines = f.readlines()

            # Prepare the new replace command
            new_line = f'replaceSelectedTexts "{csv_path}"\n'
            new_line = new_line.replace('\\', '/')

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

    def edit_in_excel(self):
        """Edit data in Excel file by opening it in Microsoft Excel"""
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        xlsx_path = os.path.join(csv_dir, file_xlsx)
        self.excel_utils.open_or_create_xlsx(xlsx_path)

        if not os.path.exists(xlsx_path):
            self.message_logger.log_message('ERROR', f"Excel file does not exist at: {xlsx_path}")
            return

        try:
            os.startfile(xlsx_path)
            self.message_logger.log_message('SUCCESS', f"Opened Excel file: {xlsx_path}")
        except Exception as e:
            self.message_logger.log_message('ERROR', f"Failed to open Excel file: {str(e)}")

    def load_from_excel(self):
        """Load data from csv file into treeview"""
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        xlsx_path = os.path.join(csv_dir, file_xlsx)

        if not xlsx_path:
            self.message_logger.log_message('ERROR', "CSV file does not exist")
            return

        success = self.excel_utils.load_excel_to_treeview(
            excel_path=xlsx_path,
            tree=self.tree
        )

        if success:
            self.message_logger.log_message('SUCCESS', f"Loaded data from {xlsx_path}")
