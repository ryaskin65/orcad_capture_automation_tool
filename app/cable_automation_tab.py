# RIGa&DeepSeek 21.12.2025
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import os
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils
from orcad_script_runner import OrcadScriptRunner
from data_converter import DataConverter
from base_tab import BaseTab
from cable_page import select_page_rows
from constants import ALL_PAGES, PAGE_DIRECTIVE
from typing import List, Tuple

script_name = 'cable.tcl'


class CableAutomationTab(BaseTab):
    def __init__(self, notebook, message_logger):
        super().__init__(notebook, message_logger)
        self.xlsx_path = ''
        self.excel_utils = ExcelUtils(message_logger)
        self.converter = DataConverter(message_logger)

        # Cached full row set from the last loaded workbook (page filtering
        # works on this snapshot instead of re-reading the file from disk).
        self._all_rows = []

        # Initialize handlers
        self.screen_handler = ScreenHandler(self.message_logger)
        self.script_runner = OrcadScriptRunner(
            self.screen_handler,
            self.message_logger,
            self.get_scripts_dir()
        )

        # Configure grid layout
        self.frame.grid_columnconfigure(0, weight=1)
        self.frame.grid_rowconfigure(0, weight=1)
        self.frame.grid_rowconfigure(1, weight=0)

        # Treeview for table
        columns = ("A", "B", "C", "D", "E", "F", "G", "H")
        self.tree = ttk.Treeview(self.frame, columns=columns, show="headings")
        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=100)
        self.tree.grid(row=0, column=0, padx=5, pady=5, sticky="nsew", columnspan=2)

        # Control panel
        control_frame = ttk.Frame(self.frame)
        control_frame.grid(row=1, column=0, padx=5, pady=5, sticky="ew")

        # Configure columns with proper weights
        control_frame.columnconfigure(0, weight=1)
        control_frame.columnconfigure(1, weight=1)
        control_frame.columnconfigure(2, weight=1)
        control_frame.columnconfigure(3, weight=1)
        control_frame.columnconfigure(4, weight=1)

        # Set fixed width for elements
        elem_width = 15

        # Page selection
        ttk.Label(control_frame, text="Page:").grid(row=0, column=0, sticky="e", padx=(0, 2))
        self.page_var = tk.StringVar(value=ALL_PAGES)
        self.page_combobox = ttk.Combobox(
            control_frame,
            textvariable=self.page_var,
            values=[ALL_PAGES],
            state="readonly",
            width=elem_width
        )
        self.page_combobox.grid(row=0, column=1, sticky="ew", padx=5)

        # Buttons
        ttk.Button(control_frame, text="Edit in Excel",
                   command=self.edit_in_excel, width=elem_width).grid(row=0, column=2, padx=(0, 5), sticky="e")
        ttk.Button(control_frame, text="Load from Excel",
                   command=self.select_and_load_from_excel, width=elem_width).grid(row=0, column=3, padx=(0, 5),
                                                                                   sticky="e")

        self.draw_button = ttk.Button(control_frame, text="Run script",
                                      command=self.draw, width=elem_width)
        self.draw_button.grid(row=0, column=4, padx=(0, 5), sticky="e")

        # Conversion button
        ttk.Button(
            control_frame,
            text="Convert Format",
            command=self.convert_file_format,
            width=15,
        ).grid(row=0, column=5, padx=(0, 5), sticky="e")

        # Scrollbar
        scrollbar = ttk.Scrollbar(self.frame, orient="vertical", command=self.tree.yview)
        scrollbar.grid(row=0, column=2, sticky="ns")
        self.tree.configure(yscrollcommand=scrollbar.set)

        self.current_page = ALL_PAGES
        self.page_var.trace_add('write', self._on_page_selection_change)

    def _populate_tree(self, rows):
        """Replace all rows in the tree with the given rows (no disk read)."""
        for item in self.tree.get_children():
            self.tree.delete(item)
        for row in rows:
            self.tree.insert("", "end", values=list(row))

    def _on_page_selection_change(self, *args):
        selected_page = self.page_var.get()
        if selected_page == self.current_page:
            return

        # Rebuild from the in-memory snapshot instead of re-reading the file.
        self._populate_tree(self._all_rows)
        if selected_page != ALL_PAGES:
            self._filter_by_page(selected_page)

        self.current_page = selected_page

    def get_page_data(self, page_name: str) -> list:
        """Rows to display for a single selected page (see cable_page)."""
        rows = [
            list(self.tree.item(item, 'values'))
            for item in self.tree.get_children()
        ]
        data = select_page_rows(rows, page_name)
        if not data:
            self.message_logger.log_message('ERROR', f"No data found for page '{page_name}'")

        return data

    def _filter_by_page(self, page_name):
        try:
            page_data = self.get_page_data(page_name)
            for item in self.tree.get_children():
                self.tree.delete(item)
            for row in page_data:
                self.tree.insert("", "end", values=row)
        except Exception as e:
            self.message_logger.log_message('ERROR', f"Filter error: {str(e)}")

    def _extract_pages_from_treeview(self) -> list:
        """Extract page names from loaded Treeview data"""
        pages = []
        for item in self.tree.get_children():
            row = list(self.tree.item(item, 'values'))
            if row and len(row) > 0 and str(row[0]).strip().upper() == PAGE_DIRECTIVE:
                if len(row) > 1 and row[1]:
                    page_name = str(row[1]).strip()
                    if page_name not in pages:
                        pages.append(page_name)
        return pages

    def edit_in_excel(self):
        """Edit data in Excel file by opening it in Microsoft Excel"""
        if not self.xlsx_path:
            self.message_logger.log_message('ERROR', "Excel path not selected")
            return

        if not os.path.exists(self.xlsx_path):
            self.message_logger.log_message('ERROR', f"Excel file does not exist at: {self.xlsx_path}")
            return

        # open_or_create_xlsx already opens the file and logs the result
        self.excel_utils.open_or_create_xlsx(self.xlsx_path)

    def load_from_excel(self):
        """Load data from Excel file into treeview and extract pages"""
        if not self.xlsx_path:
            self.message_logger.log_message('ERROR', "Excel path not selected")
            return

        if not os.path.exists(self.xlsx_path):
            self.message_logger.log_message('ERROR', "Excel file does not exist")
            return

        success = self.excel_utils.load_excel_to_treeview(
            excel_path=self.xlsx_path,
            tree=self.tree
        )

        if success:
            # Snapshot the full row set so page filtering never re-reads disk.
            self._all_rows = [
                list(self.tree.item(item, 'values'))
                for item in self.tree.get_children()
            ]
            pages = self._extract_pages_from_treeview()
            self.page_combobox['values'] = [ALL_PAGES] + pages
            self.current_page = ALL_PAGES
            self.page_var.set(ALL_PAGES)
            self.message_logger.log_message('SUCCESS', f"Loaded data from {self.xlsx_path}")

    def select_and_load_from_excel(self):
        data_dir = self.get_data_dir()
        initial_dir = data_dir if os.path.exists(data_dir) else None

        selected = filedialog.askopenfilename(
            filetypes=[("Excel files", "*.xlsx *.xls")],
            initialdir=initial_dir
        )
        if selected:
            self.xlsx_path = selected
            self.load_from_excel()

    def _on_execution_complete(self, result):
        """Callback for script execution completion"""
        self.draw_button.config(state='normal', text='Run script')
        if not result['success']:
            self.message_logger.log_message('ERROR', f"Script execution failed: {result.get('error', 'Unknown error')}")

    def validate_input_file(
        self, input_path: str, for_drawing: bool = False
    ) -> Tuple[bool, List[str], List[str]]:
        """
        Common validation method for both conversion and drawing

        Args:
            input_path: Path to Excel file
            for_drawing: True if validating for drawing (additional checks)

        Returns: (is_valid, errors, warnings)
        """
        if not input_path:
            return False, ["No Excel file selected"], []

        if not os.path.exists(input_path):
            return False, [f"Excel file does not exist: {input_path}"], []

        # Use converter's validation
        return self.converter.validate_input_data(input_path)

    def convert_file_format(self):
        """Convert Excel file from input to output format"""
        if not self.xlsx_path:
            self.message_logger.log_message("ERROR", "No Excel file selected")
            return

        # Validate using common method
        success, errors, warnings = self.validate_input_file(
            self.xlsx_path, for_drawing=False
        )

        # Log all messages
        for error in errors:
            self.message_logger.log_message("ERROR", error)
        for warning in warnings:
            self.message_logger.log_message("WARNING", warning)

        if not success:
            self.message_logger.log_message(
                "ERROR", "Validation failed - cannot convert file"
            )
            return

        # Create output path
        input_dir = os.path.dirname(self.xlsx_path)
        input_name = os.path.splitext(os.path.basename(self.xlsx_path))[0]
        output_path = os.path.join(input_dir, f"{input_name}_converted.xlsx")

        # Convert file
        success, conv_errors, conv_warnings = self.converter.convert_excel_file(
            self.xlsx_path, output_path
        )

        # Log conversion results
        for error in conv_errors:
            self.message_logger.log_message("ERROR", error)
        for warning in conv_warnings:
            self.message_logger.log_message("WARNING", warning)

        if success:
            self.message_logger.log_message(
                "SUCCESS", f"File converted successfully: {output_path}"
            )
        else:
            self.message_logger.log_message("ERROR", "File conversion failed")

    def _convert_data_for_drawing(self, input_path: str):
        """Convert data after successful validation"""
        try:
            from openpyxl import load_workbook

            input_wb = load_workbook(input_path)
            input_ws = input_wb.active

            # Parse input data
            input_data = self.converter._parse_input_worksheet(input_ws)
            if not input_data:
                return False, []

            # Calculate all wire data
            success = self.converter._calculate_all_wire_data(input_data)
            if not success:
                return False, []

            # Convert data format
            success, converted_data = self.converter._convert_and_process_data(
                input_data
            )
            return success, converted_data

        except Exception as e:
            self.message_logger.log_message("ERROR", f"Conversion error: {str(e)}")
            return False, []

    def _load_converted_data_to_treeview(self, converted_data: list):
        """Load converted data directly to treeview"""
        # Clear existing data
        for item in self.tree.get_children():
            self.tree.delete(item)

        # Insert converted data
        for row in converted_data:
            # Convert None to empty strings
            cleaned_row = ["" if cell is None else str(cell) for cell in row]
            self.tree.insert("", "end", values=cleaned_row)

    def draw(self):
        """Handle draw action with validation"""
        try:
            # Validate AND convert before drawing
            if not self.validate_before_draw():
                return

            # Use the converted data from validate_before_draw()
            if not hasattr(self, "converted_data") or not self.converted_data:
                self.message_logger.log_message("ERROR", "No converted data available")
                return

            # Convert to CSV in data directory
            csv_filename = "cable.csv"
            csv_path = os.path.join(self.get_data_dir(), csv_filename)

            # Save converted data directly to CSV
            success = self.excel_utils.save_list_to_csv(
                data=self.converted_data, csv_path=csv_path
            )

            if not success:
                self.message_logger.log_message("ERROR", "Failed to save CSV file")
                return

            glob_var = [["::path_to_csv_file", csv_path.replace("\\", "/")]]

            # Execute the script
            success = self.script_runner.execute_script(
                script_name, glob_var, self._on_execution_complete
            )

            if success:
                self.draw_button.config(state="disabled", text="Running...")

        except Exception as e:
            self.message_logger.log_message("ERROR", f"Error during drawing: {str(e)}")
            self.draw_button.config(state="normal", text="Run script")

    def validate_before_draw(self):
        """Validate cable data before running the script"""
        try:
            if not self.xlsx_path:
                self.message_logger.log_message("ERROR", "No Excel file selected")
                return False

            # Validate using common method
            success, errors, warnings = self.validate_input_file(
                self.xlsx_path, for_drawing=True
            )

            # Log all messages
            for error in errors:
                self.message_logger.log_message("ERROR", error)
            for warning in warnings:
                self.message_logger.log_message("WARNING", warning)

            if not success:
                self.message_logger.log_message(
                    "ERROR", "Validation failed - cannot run script"
                )
                return False

            # Convert data for drawing
            success, converted_data = self._convert_data_for_drawing(self.xlsx_path)

            if not success:
                self.message_logger.log_message(
                    "ERROR", "Failed to convert data for drawing"
                )
                return False

            self.converted_data = converted_data
            self._load_converted_data_to_treeview(converted_data)

            self.message_logger.log_message(
                "SUCCESS", "Data validated successfully - ready to draw"
            )
            return True

        except Exception as e:
            self.message_logger.log_message("ERROR", f"Validation error: {str(e)}")
            return False

