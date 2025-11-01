# RIGa&DeepSeek 26.10.2025
import tkinter as tk
from tkinter import ttk, filedialog
import os
import sys
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils
from orcad_script_runner import OrcadScriptRunner

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

        # Initialize ScreenHandler and ScriptRunner
        self.screen_handler = ScreenHandler(self.message_logger)
        self.script_runner = OrcadScriptRunner(
            self.screen_handler,
            self.message_logger,
            self.get_scripts_dir()
        )

        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_columnconfigure(1, weight=0, minsize=50)
        self.frame.grid_rowconfigure(0, weight=1)
        self.frame.grid_rowconfigure(1, weight=0)

        # Treeview for table - initially empty, will be configured dynamically
        self.tree = ttk.Treeview(self.frame, columns=(), show="headings")
        self.tree.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        # Add scrollbar for treeview
        tree_scroll = ttk.Scrollbar(self.frame, orient="vertical", command=self.tree.yview)
        tree_scroll.grid(row=0, column=0, sticky="nse", padx=(0, 5), pady=5)
        self.tree.configure(yscrollcommand=tree_scroll.set)

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

        # Store references to buttons
        self.edit_excel_btn = ttk.Button(radio_frame, text="Edit in Excel",
                                         command=self.edit_in_excel)
        self.edit_excel_btn.pack(anchor="e", pady=(20, 5), fill='x')

        self.load_excel_btn = ttk.Button(radio_frame, text="Load from csv",
                                         command=self.load_from_excel)
        self.load_excel_btn.pack(anchor="e", pady=(20, 5), fill='x')

        self.copy_btn = ttk.Button(radio_frame, text="Copy X, Y, names", command=self.copy_offpage)
        self.copy_btn.pack(anchor="e", pady=(20, 5), fill='x')

        self.replace_btn = ttk.Button(radio_frame, text="Replace names", command=self.replace_offpage)
        self.replace_btn.pack(anchor="e", pady=(20, 5), fill='x')

        self.change_dir_btn = ttk.Button(radio_frame, text="Change direction", command=self.change_direction)
        self.change_dir_btn.pack(anchor="e", pady=(20, 5), fill='x')

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

    def _execute_script_with_csv(self, script_name, button, auto_load=False):
        """Common method to execute scripts with CSV file"""
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)

        glob_var = [["::path_to_csv_file", csv_path.replace('\\', '/')]]

        def execution_callback(result):
            button.config(state='normal')
            if result['success']:
                self.message_logger.log_message('SUCCESS', f"Script {script_name} executed successfully")
                # Auto-load table after successful copy
                if auto_load:
                    self.load_from_excel()
            else:
                self.message_logger.log_message('ERROR',
                                                f"Script execution failed: {result.get('error', 'Unknown error')}")

        # Update button state
        button.config(state='disabled')

        # Execute the script
        success = self.script_runner.execute_script(script_name, glob_var, execution_callback)

        if not success:
            button.config(state='normal')

    def copy_offpage(self):
        """Copy offpage connector data with auto-load after success"""
        self._execute_script_with_csv(script_copy_off, self.copy_btn, auto_load=True)

    def replace_offpage(self):
        """Replace offpage connector names"""
        self._execute_script_with_csv(script_repl_off, self.replace_btn)

    def change_direction(self):
        """Change offpage connector direction"""
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_change_dir_off)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        def execution_callback(result):
            self.change_dir_btn.config(state='normal')
            if result['success']:
                self.message_logger.log_message('SUCCESS', "Offpage directions changed successfully")
            else:
                self.message_logger.log_message('ERROR',
                                                f"Script execution failed: {result.get('error', 'Unknown error')}")

        # Update button state
        self.change_dir_btn.config(state='disabled')

        # Execute the script
        success = self.script_runner.execute_script(script_change_dir_off, [], execution_callback)

        if not success:
            self.change_dir_btn.config(state='normal')

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
                # Create data directory if it doesn't exist
                os.makedirs(csv_dir, exist_ok=True)
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
        """Load data from configured CSV file into treeview with dynamic columns"""
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
        else:
            self.message_logger.log_message('ERROR', f"Failed to load data from {csv_path}")
