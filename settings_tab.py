# settings_tab.py
import tkinter as tk
from tkinter import ttk, filedialog
import json
import os

class SettingsTab:
    def __init__(self, notebook, message_logger):
        self.message_logger = message_logger
        self.frame = ttk.Frame(notebook)
        self.config_file = 'config.json'
        self.config = {}

        # Define field configurations
        self.fields = [
            # {"label": "Complex Replace Excel", "key": "complex_replace_excel", "filetypes": [("Excel files", "*.xlsx *.xls")]},
            {"label": "Cable Drawing Excel", "key": "cable_drawing_excel", "filetypes": [("Excel files", "*.xlsx *.xls")]},
            # {"label": "OffPageConnector Copy CSV", "key": "off_page_copy_excel", "filetypes": [("CSV files", "*.csv *.csv")]},
            # {"label": "Test Script", "key": "test_script", "filetypes": [("Script files", "*.tcl")]}
        ]

        # Initialize UI
        self.entries = {}
        self.create_widgets()
        self.load_config()

    def create_widgets(self):
        """Create all widgets for the settings tab."""
        self.frame.columnconfigure(0, weight=1)
        self.frame.columnconfigure(1, weight=3)
        self.frame.columnconfigure(2, weight=0)

        for row, field in enumerate(self.fields):
            # Label
            ttk.Label(self.frame, text=f"{field['label']}:").grid(
                row=row, column=0, padx=5, pady=5, sticky="e")

            # Entry
            entry = ttk.Entry(self.frame, width=50)
            entry.grid(row=row, column=1, padx=5, pady=5, sticky="ew")
            self.entries[field['key']] = entry

            # Browse Button
            ttk.Button(self.frame, text="Browse...",
                       command=lambda f=field['key'], ft=field['filetypes']: self.browse_file(f, ft)
                       ).grid(row=row, column=2, padx=5, pady=5)

        # Buttons frame
        buttons_frame = ttk.Frame(self.frame)
        buttons_frame.grid(row=len(self.fields), column=0, columnspan=3, pady=10)
        ttk.Button(buttons_frame, text="Load", command=self.load_config).pack(side="left", padx=5)
        ttk.Button(buttons_frame, text="Save", command=self.save_config).pack(side="left", padx=5)

    def browse_file(self, field_name, filetypes):
        """Open file selection dialog for specific field."""
        file_path = filedialog.askopenfilename(filetypes=filetypes)
        if file_path and field_name in self.entries:
            entry = self.entries[field_name]
            entry.delete(0, tk.END)
            entry.insert(0, file_path)

    def load_config(self):
        """Load configuration from JSON file."""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.config = json.load(f)

                # Update UI fields
                for field in self.fields:
                    key = field['key']
                    entry = self.entries[key]
                    entry.delete(0, tk.END)
                    entry.insert(0, self.config.get(f"{key}_script" if "excel" not in key else key, ''))

                self.message_logger.log_message('SUCCESS', 'Configuration loaded successfully')
            else:
                self.message_logger.log_message('WARNING', 'Configuration file not found, using defaults')
        except Exception as e:
            self.message_logger.log_message('ERROR', f'Error loading configuration: {str(e)}')

    def save_config(self):
        """Save configuration to JSON file."""
        try:
            self.config = {
                f"{field['key']}_script" if "excel" not in field['key'] else field['key']:
                    self.entries[field['key']].get() for field in self.fields
            }

            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=4)

            self.message_logger.log_message('SUCCESS', 'Configuration saved successfully')
        except Exception as e:
            self.message_logger.log_message('ERROR', f'Error saving configuration: {str(e)}')
