import tkinter as tk
from tkinter import ttk, filedialog
import os
import sys
from screen_handler import ScreenHandler
from excel_utils import ExcelUtils

script_name = 'cable.tcl'
xlsx_path = ''

class CableDraw:
    def __init__(self, notebook, message_logger):
        self.message_logger = message_logger
        self.excel_utils = ExcelUtils(message_logger)
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler
        self.screen_handler = ScreenHandler(self.message_logger)

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

        # Control panel (now in one row)
        control_frame = ttk.Frame(self.frame)
        control_frame.grid(row=1, column=0, padx=5, pady=5, sticky="ew")

        # Configure columns with proper weights
        control_frame.columnconfigure(0, weight=1)  # Label
        control_frame.columnconfigure(1, weight=1)  # Combobox
        control_frame.columnconfigure(2, weight=1)  # Spacer
        control_frame.columnconfigure(3, weight=1)  # Load button
        control_frame.columnconfigure(4, weight=1)  # Draw button

        # Set fixed width for elements
        elem_width = 15  # Same width for all interactive elements

        # Page selection
        ttk.Label(control_frame, text="Page:").grid(row=0, column=0, sticky="e", padx=(0, 2))

        self.page_var = tk.StringVar(value="all")
        self.page_combobox = ttk.Combobox(
            control_frame,
            textvariable=self.page_var,
            values=["all"],
            state="readonly",
            width=elem_width
        )
        self.page_combobox.grid(row=0, column=1, sticky="ew", padx=5)

        # Buttons
        ttk.Button(control_frame, text="Edit in Excel",
            command=self.edit_in_excel, width = elem_width).grid(row=0, column=2, padx=(0, 5), sticky="e")
        ttk.Button(control_frame, text="Load from Excel",
            command=self.select_and_load_from_excel, width = elem_width).grid(row=0, column=3, padx=(0, 5), sticky="e")
        ttk.Button(control_frame, text="Run script",
            command=self.draw, width = elem_width).grid(row=0, column=4, padx=(0, 5), sticky="e")

        # Scrollbar
        scrollbar = ttk.Scrollbar(self.frame, orient="vertical", command=self.tree.yview)
        scrollbar.grid(row=0, column=2, sticky="ns")
        self.tree.configure(yscrollcommand=scrollbar.set)

        self.current_page = "all"
        self.page_var.trace_add('write', self._on_page_selection_change)

    def _on_page_selection_change(self, *args):
        selected_page = self.page_var.get()

        if selected_page == self.current_page:
            return

        self.load_from_excel()
        if selected_page != "all":
            self._filter_by_page(selected_page)

        self.page_var.set(selected_page)
        self.current_page = selected_page

    def get_page_data(self, page_name: str) -> list:
        data = []
        collect_page = False
        page_data = False
        empty_row_added = False
        directive = ''
        value_directive = ''


        for item in self.tree.get_children():
            # row = self.tree.item(item)['values'] - do not use!!!
            row = list(self.tree.item(item, 'values'))

            # If empty row - break after fill page
            if not row or not any(cell and str(cell).strip() for cell in row):
                empty_row = True
                if page_data:
                    page_data = False
                    if collect_page:
                        break
            else:
                empty_row = False

            if not page_data and row[0]:
                directive = str(row[0]).strip().upper()
                if len(row) > 1:
                    value_directive = str(row[1]).strip()
                else:
                    value_directive = ''
                # Check for PAGE directive
                if directive == "PAGE":
                    page_data = True
                    collect_page = (value_directive == page_name)

            def find_directive():
                for i, arr_row in enumerate(data):
                    if arr_row and len(arr_row) > 0:
                        arr_directive = str(arr_row[0]).strip().upper()
                        if arr_directive == "PAGE":
                            return False
                        if arr_directive == directive:
                            data[i][1] = value_directive
                            return True
                return False

            # Collect data if in the target section
            if collect_page:
                data.append(row)
                empty_row_added = False
            elif not page_data:
                if not empty_row:
                    empty_row = find_directive()
                    if not empty_row:
                        data.append(row)
                    elif not empty_row_added:
                        data.append(row)
                if empty_row:
                    empty_row_added = True
                else:
                    empty_row_added = False

        if not data:
            self.message_logger.log_message('ERROR', f"No data found for page '{page_name}'")

        return data

    def _filter_by_page(self, page_name):
        try:
            page_data = self.get_page_data(page_name)

            for item in self.tree.get_children():
                self.tree.delete(item)

            for row in page_data :
                self.tree.insert("", "end", values=row)

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Filter error: {str(e)}")

    def _extract_pages_from_treeview(self) -> list:
        """Extract page names from loaded Treeview data"""
        pages = []
        for item in self.tree.get_children():
            row = list(self.tree.item(item, 'values'))
            if row and len(row) > 0 and str(row[0]).strip().upper() == "PAGE":
                if len(row) > 1 and row[1]:  # Check if page name exists
                    page_name = str(row[1]).strip()
                    if page_name not in pages:  # Avoid duplicates
                        pages.append(page_name)
        return pages

    def edit_in_excel(self):
        """Edit data in Excel file by opening it in Microsoft Excel"""
        if not xlsx_path:
            self.message_logger.log_message('ERROR', "Excel path not selected")
            return

        if not os.path.exists(xlsx_path):
            self.message_logger.log_message('ERROR', f"Excel file does not exist at: {xlsx_path}")
            return

        self.excel_utils.open_or_create_xlsx(xlsx_path)

        try:
            os.startfile(xlsx_path)
            self.message_logger.log_message('SUCCESS', f"Opened Excel file: {xlsx_path}")
        except Exception as e:
            self.message_logger.log_message('ERROR', f"Failed to open Excel file: {str(e)}")

    def load_from_excel(self):
        """Load data from Excel file into treeview and extract pages"""
        if not xlsx_path:
            self.message_logger.log_message('ERROR', "Excel path not selected")
            return

        if not os.path.exists(xlsx_path):
            self.message_logger.log_message('ERROR', "Excel file does not exist")
            return

        # Load Excel data using existing method
        success = self.excel_utils.load_excel_to_treeview(
            excel_path=xlsx_path,
            tree=self.tree
        )

        if success:
            # Extract pages from loaded treeview data
            pages = self._extract_pages_from_treeview()
            self.page_combobox['values'] = ["all"] + pages
            self.current_page = "all"
            self.page_var.set("all")
            self.message_logger.log_message('SUCCESS', f"Loaded data from {xlsx_path}")

    def select_and_load_from_excel(self):
        global xlsx_path
        xlsx_path = filedialog.askopenfilename(filetypes=[("Excel files", "*.xlsx *.xls")])
        self.load_from_excel()

    def draw(self):
        """Handle draw action with page selection"""
        try:
            if not self.tree.get_children():
                self.load_from_excel()
                if not self.tree.get_children():
                    self.message_logger.log_message('ERROR', "No data to draw")
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

            if not xlsx_path:
                self.message_logger.log_message('ERROR', "Excel path not configured")
                return

            if not os.path.exists(xlsx_path):
                self.message_logger.log_message('ERROR', "Excel file does not exist")
                return

            csv_path = xlsx_path[:-5] + '.csv'

            data = []
            for item in self.tree.get_children():
                row = list(self.tree.item(item, 'values'))
                data.append(row)

            self.excel_utils.save_list_to_csv(
                data=data,
                csv_path=csv_path
            )

            # Update script file
            with open(script_path, "r") as f:
                lines = f.readlines()

            new_line = f'drawCable "{csv_path}"\n'

            if lines and lines[-1].strip().startswith("drawCable"):
                lines[-1] = new_line
            else:
                lines.append(new_line)

            with open(script_path, "w") as f:
                f.writelines(lines)

            # Execute in OrCAD
            self.screen_handler.execute_in_orcad(script_path, self.message_logger)

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Error during drawing: {str(e)}")
