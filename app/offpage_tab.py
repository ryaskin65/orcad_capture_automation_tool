# RIGa&AI 16.01.2026
import tkinter as tk
from tkinter import ttk
import os
import sys
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils
from orcad_script_runner import OrcadScriptRunner
from offpage_analyzer import OffPageAnalyzer
# from datetime import datetime
# from tkinter import messagebox

script_copy_off = "copy_offpage.tcl"
script_repl_off = "replace_offpage.tcl"
script_change_dir_off = "change_dir_offpage.tcl"
file_csv = "offpage.csv"
script_copy_port = "copy_port.tcl"
# script_repl_port = "replace_port.tcl"
# script_change_dir_port = "change_dir_port.tcl"


class OffPageTab:
    def __init__(self, notebook, message_logger):
        """Initialize TableTab with notebook and message variable."""
        self.message_logger = message_logger
        self.excel_utils = ExcelUtils(message_logger)
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler and ScriptRunner
        self.screen_handler = ScreenHandler(self.message_logger)
        self.script_runner = OrcadScriptRunner(
            self.screen_handler, self.message_logger, self.get_scripts_dir()
        )

        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_columnconfigure(1, weight=0, minsize=50)
        self.frame.grid_rowconfigure(0, weight=1)
        self.frame.grid_rowconfigure(1, weight=0)

        # Treeview for table - initially empty, will be configured dynamically
        self.tree = ttk.Treeview(self.frame, columns=(), show="headings")
        self.tree.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        # Add scrollbar for treeview
        tree_scroll = ttk.Scrollbar(
            self.frame, orient="vertical", command=self.tree.yview
        )
        tree_scroll.grid(row=0, column=0, sticky="nse", padx=(0, 5), pady=5)
        self.tree.configure(yscrollcommand=tree_scroll.set)

        radio_frame = ttk.Frame(self.frame)
        radio_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")

        # Radiobuttons for scope (right side)
        self.scope_var = tk.StringVar(value="PAGE")  # Default to Selected Objects
        ttk.Radiobutton(
            radio_frame,
            text="Active Page",
            variable=self.scope_var,
            value="PAGE",
            state="enabled",
        ).pack(anchor="w", pady=5)
        ttk.Radiobutton(
            radio_frame,
            text="All Pages",
            variable=self.scope_var,
            value="ALL",
            state="enabled",
        ).pack(anchor="w", pady=5)

        # Radiobuttons for off-page - port scope (right side)
        self.scope_var_type = tk.StringVar(value="OFF-PAGE")  # Default to Selected Objects
        ttk.Radiobutton(
            radio_frame,
            text="Off-Page Connector",
            variable=self.scope_var_type,
            value="OFF-PAGE",
            state="enabled",
        ).pack(anchor="w", pady=5)
        ttk.Radiobutton(
            radio_frame,
            text="Port",
            variable=self.scope_var_type,
            value="PORT",
            state="enabled",
        ).pack(anchor="w", pady=5)
        ttk.Radiobutton(
            radio_frame,
            text="Off-Page & Port",
            variable=self.scope_var_type,
            value="OFF&PORT",
            state="disabled",
        ).pack(anchor="w", pady=5)

        self.load_excel_btn = ttk.Button(
            radio_frame, text="Load from csv", command=self.load_from_excel
        )
        self.load_excel_btn.pack(anchor="e", pady=(20, 5), fill="x")

        self.copy_btn = ttk.Button(
            radio_frame, text="Copy X, Y, names", command=self.copy_offpage
        )
        self.copy_btn.pack(anchor="e", pady=(20, 5), fill="x")

        self.replace_btn = ttk.Button(
            radio_frame, text="Replace names", command=self.replace_offpage
        )
        self.replace_btn.pack(anchor="e", pady=(20, 5), fill="x")

        self.change_dir_btn = ttk.Button(
            radio_frame, text="Change direction", command=self.change_direction
        )
        self.change_dir_btn.pack(anchor="e", pady=(20, 5), fill="x")

        self.change_dir_btn = ttk.Button(
            radio_frame, text="Analise", command=self.analise_offpage
        )
        self.change_dir_btn.pack(anchor="e", pady=(20, 5), fill="x")

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

    def _execute_script_with_csv(self, script_name, button, scoupe, auto_load=False):
        """Common method to execute scripts with CSV file"""
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message(
                "ERROR", f'Script file "{script_path}" not found!'
            )
            return

        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, file_csv)

        glob_var = [["::path_to_csv_file", csv_path.replace("\\", "/")],
                    ["::EXPORT_SCOPE", scoupe]]

        def execution_callback(result):
            button.config(state="normal")
            if result["success"]:
                self.message_logger.log_message(
                    "SUCCESS", f"Script {script_name} executed successfully"
                )
                # Auto-load table after successful copy
                if auto_load:
                    self.load_from_excel()
            else:
                self.message_logger.log_message(
                    "ERROR",
                    f"Script execution failed: {result.get('error', 'Unknown error')}",
                )

        # Update button state
        button.config(state="disabled")

        # Execute the script
        success = self.script_runner.execute_script(
            script_name, glob_var, execution_callback
        )

        if not success:
            button.config(state="normal")

    def copy_offpage(self):
        """Copy offpage connector data with auto-load after success"""
        scope = self.scope_var.get()
        scope_type = self.scope_var_type.get()
        if scope_type == "OFF-PAGE":
            self._execute_script_with_csv(script_copy_off, self.copy_btn, scope,True)
        elif scope_type == "PORT":
            self._execute_script_with_csv(script_copy_port, self.copy_btn, scope,True)

    def replace_offpage(self):
        """Replace offpage connector names"""
        self._execute_script_with_csv(script_repl_off, self.replace_btn, "OFF-PAGE",False)

    def change_direction(self):
        """Change offpage connector direction"""
        scripts_dir = self.get_scripts_dir()
        script_path = os.path.join(scripts_dir, script_change_dir_off)

        if not os.path.exists(script_path):
            self.message_logger.log_message(
                "ERROR", f'Script file "{script_path}" not found!'
            )
            return

        def execution_callback(result):
            self.change_dir_btn.config(state="normal")
            if result["success"]:
                self.message_logger.log_message(
                    "SUCCESS", "Offpage directions changed successfully"
                )
            else:
                self.message_logger.log_message(
                    "ERROR",
                    f"Script execution failed: {result.get('error', 'Unknown error')}",
                )

        # Update button state
        self.change_dir_btn.config(state="disabled")

        # Execute the script
        success = self.script_runner.execute_script(
            script_change_dir_off, [], execution_callback
        )

        if not success:
            self.change_dir_btn.config(state="normal")

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
                with open(csv_path, "w") as f:
                    f.write("")  # Create empty file
                self.message_logger.log_message(
                    "SUCCESS", f"Created new CSV file: {csv_path}"
                )

            # Check if file is already open (locked)
            if self._is_file_locked(csv_path):
                self.message_logger.log_message(
                    "ERROR", f"File is already open: {csv_path}"
                )
                return

            # Open the CSV file in Excel
            os.startfile(csv_path)
            self.message_logger.log_message(
                "SUCCESS", f"Opened CSV file in Excel: {csv_path}"
            )

        except Exception as e:
            self.message_logger.log_message(
                "ERROR", f"Failed to open CSV file: {str(e)}"
            )

    def _is_file_locked(self, filepath):
        """Check if file is locked by attempting to open it in exclusive mode"""
        try:
            if os.path.exists(filepath):
                with open(filepath, "a", encoding="utf-8") as f:
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

    def analise_offpage(self):
        """Analyze offpage connector data and generate Excel report"""
        scope_type = self.scope_var_type.get()

        # Determine which CSV file to analyze based on selected type
        csv_filename = "offpage.csv"

        # Get paths
        scripts_dir = self.get_scripts_dir()
        csv_dir = os.path.join(os.path.dirname(scripts_dir), "data")
        csv_path = os.path.join(csv_dir, csv_filename)

        # Generate report path
        # timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        # report_filename = f"{scope_type.lower()}_analysis_{timestamp}.xlsx"
        report_filename = "analysis.xlsx"
        report_path = os.path.join(csv_dir, report_filename)

        if not os.path.exists(csv_path):
            self.message_logger.log_message(
                "ERROR", f"CSV file not found: {csv_filename}"
            )
            return

        # Update button state
        self.change_dir_btn.config(state="disabled")
        self.message_logger.log_message(
            "INFO", f"Starting analysis of {csv_filename}..."
        )

        try:
            # Create analyzer and run analysis
            analyzer = OffPageAnalyzer(self.message_logger)
            success = analyzer.analyze_and_generate_report(csv_path, report_path)

            if success:
                self.message_logger.log_message(
                    "SUCCESS", f"Analysis completed. Report saved to: {report_path}"
                )

                try:
                    os.startfile(report_path)
                    self.message_logger.log_message(
                        "INFO", f"Opened report: {report_path}"
                    )
                except Exception as e:
                    self.message_logger.log_message(
                        "ERROR", f"Failed to open report: {str(e)}"
                    )

        except Exception as e:
            self.message_logger.log_message("ERROR", f"Analysis failed: {str(e)}")
        finally:
            # Restore button state
            self.change_dir_btn.config(state="normal")
