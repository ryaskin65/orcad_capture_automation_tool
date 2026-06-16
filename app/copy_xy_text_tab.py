# RIGa&DeepSeek 05.11.2025
from tkinter import ttk
import os
from screen_handler import ScreenHandler
from base_tab import BaseTab
from excel_utils import ExcelUtils
from orcad_script_runner import OrcadScriptRunner

script_copy_text = "copy_xy_text.tcl"
file_csv = "selected_text.csv"


class CopyXYTextTab(BaseTab):
    def __init__(self, notebook, message_logger):
        """Initialize CopyTextTab with notebook and message logger."""
        super().__init__(notebook, message_logger)
        self.excel_utils = ExcelUtils(message_logger)

        # Initialize ScreenHandler and ScriptRunner
        self.screen_handler = ScreenHandler(self.message_logger)
        self.script_runner = OrcadScriptRunner(
            self.screen_handler, self.message_logger, self.get_scripts_dir()
        )

        # Grid configuration
        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_columnconfigure(1, weight=0, minsize=50)
        self.frame.grid_rowconfigure(0, weight=1)

        # Treeview for displaying CSV data
        self.tree = ttk.Treeview(self.frame, columns=(), show="headings")
        self.tree.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        # Scrollbar
        tree_scroll = ttk.Scrollbar(
            self.frame, orient="vertical", command=self.tree.yview
        )
        tree_scroll.grid(row=0, column=0, sticky="nse", padx=(0, 5), pady=5)
        self.tree.configure(yscrollcommand=tree_scroll.set)

        # Right panel with buttons
        button_frame = ttk.Frame(self.frame)
        button_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")

        self.edit_excel_btn = ttk.Button(
            button_frame, text="Edit in Excel", command=self.edit_in_excel
        )
        self.edit_excel_btn.pack(anchor="e", pady=(20, 5), fill="x")

        self.load_excel_btn = ttk.Button(
            button_frame, text="Load from csv", command=self.load_from_excel
        )
        self.load_excel_btn.pack(anchor="e", pady=(20, 5), fill="x")

        self.copy_btn = ttk.Button(
            button_frame, text="Copy selected text", command=self.copy_text
        )
        self.copy_btn.pack(anchor="e", pady=(20, 5), fill="x")


    def _execute_script_with_csv(self, script_name, button, auto_load=False):
        """Common method to execute script with CSV and handle callback"""
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message(
                "ERROR", f'Script file "{script_path}" not found!'
            )
            return

        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)
        glob_var = [["::path_to_csv_file", csv_path.replace("\\", "/")]]

        def execution_callback(result):
            button.config(state="normal")
            if result["success"]:
                self.message_logger.log_message(
                    "SUCCESS", f"Script {script_name} executed successfully"
                )
                if auto_load:
                    self.load_from_excel()
            else:
                self.message_logger.log_message(
                    "ERROR",
                    f"Script execution failed: {result.get('error', 'Unknown error')}",
                )

        button.config(state="disabled")
        success = self.script_runner.execute_script(
            script_name, glob_var, execution_callback
        )

        if not success:
            button.config(state="normal")

    def copy_text(self):
        """Copy selected text in OrCAD and save to CSV"""
        self._execute_script_with_csv(script_copy_text, self.copy_btn, auto_load=True)

    def edit_in_excel(self):
        """Open CSV file in Excel. Create if not exists. Check for lock."""
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)

        try:
            # Create directory and empty file if not exists
            if not os.path.exists(csv_path):
                os.makedirs(csv_dir, exist_ok=True)
                with open(csv_path, "w", encoding="utf-8") as f:
                    f.write("")
                self.message_logger.log_message(
                    "SUCCESS", f"Created new CSV file: {csv_path}"
                )

            # Check if file is locked
            if self._is_file_locked(csv_path):
                self.message_logger.log_message(
                    "ERROR", f"File is already open in Excel: {csv_path}"
                )
                return

            # Open in Excel
            os.startfile(csv_path)
            self.message_logger.log_message(
                "SUCCESS", f"Opened CSV in Excel: {csv_path}"
            )

        except Exception as e:
            self.message_logger.log_message("ERROR", f"Failed to open file: {str(e)}")


    def load_from_excel(self):
        """Load CSV data into Treeview with dynamic columns"""
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)

        if not os.path.exists(csv_path):
            self.message_logger.log_message("ERROR", "CSV file does not exist")
            return

        success = self.excel_utils.load_csv_to_treeview(
            csv_path=csv_path, tree=self.tree
        )

        if success:
            self.message_logger.log_message("SUCCESS", f"Loaded data from {csv_path}")
        else:
            self.message_logger.log_message(
                "ERROR", f"Failed to load data from {csv_path}"
            )
