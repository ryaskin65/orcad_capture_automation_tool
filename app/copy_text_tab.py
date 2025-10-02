import tkinter as tk
from tkinter import ttk, filedialog
import os
import sys
from screen_handler import ScreenHandler

script_name = 'copy_text.tcl'
file_csv = 'selected_text.csv'

class CopyTextTab:
    def __init__(self, notebook, message_logger):
        self.message_logger = message_logger
        self.frame = ttk.Frame(notebook)

        # Initialize ScreenHandler with MessageLogger
        self.screen_handler = ScreenHandler(self.message_logger)

        # Text editor
        self.text_area = tk.Text(self.frame, height=20, width=95)
        self.text_area.grid(row=0, column=0, columnspan=4, padx=5, pady=5)

        # Buttons
        ttk.Button(self.frame, text="Save to File", command=self.save_file).grid(row=1, column=0, padx=5, pady=5)
        ttk.Button(self.frame, text="Clear", command=self.clear_text).grid(row=1, column=1, padx=5, pady=5)
        ttk.Button(self.frame, text="Run script", command=self.copy_text).grid(row=1, column=2, padx=5, pady=5)
        ttk.Button(self.frame, text="Load text", command=self.load_text).grid(row=1, column=3, padx=5, pady=5)

        # Bind keyboard shortcuts
        self.text_area.bind("<Control-a>", self.select_all)
        self.text_area.bind("<Control-c>", lambda e: self.text_area.event_generate("<<Copy>>"))
        self.text_area.bind("<Control-v>", lambda e: self.text_area.event_generate("<<Paste>>"))
        self.text_area.bind("<Control-x>", lambda e: self.text_area.event_generate("<<Cut>>"))
        self.text_area.bind("<Control-s>", self.save_file)

    def save_file(self, event=None):
        """Save text to a file."""
        file_path = filedialog.asksaveasfilename(defaultextension=".txt",
                                                 filetypes=[("Text files", "*.txt"), ("All files", "*.*")])
        if file_path:
            with open(file_path, "w") as f:
                f.write(self.text_area.get("1.0", tk.END))
            self.message_logger.log_message(f"File saved to {file_path}")
        return "break"

    def clear_text(self):
        """Clear the text area."""
        self.text_area.delete("1.0", tk.END)
        self.message_logger.log_message('SUCCESS', "Text cleared.")

    def copy_text(self):
        """Copy the text area."""
        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()
        script_path = os.path.join(app_dir, script_name)

        if not os.path.exists(script_path):
            self.message_logger.log_message('ERROR', f'Script file "{script_path}" not found!')
            return

        csv_path = os.path.join(app_dir, file_csv)

        # if not os.path.exists(csv_path):
        #     self.message_logger.log_message('ERROR', f'File "{csv_path}" not found!')
        #     return

        try:
            # Read or create the script file
            with open(script_path, "r") as f:
                lines = f.readlines()

            # Prepare the new replace command
            new_line = f'saveSelectedText "{csv_path}"\n'
            new_line = new_line.replace('\\', '/')

            # Replace or append the last line
            if lines and lines[-1].strip().startswith("saveSelectedText"):
                lines[-1] = new_line
            else:
                lines.append(new_line)

            # Save the updated script
            with open(script_path, "w") as f:
                f.writelines(lines)

            # Execute the script in OrCAD
            self.screen_handler.execute_in_orcad(script_path, self.message_logger)

            # self.message_logger.log_message('SUCCESS',
            #                                 f"Updated {script_path} "
            #                                 f"with '{csv_path}' in {scope_text}")

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Error updating script: {str(e)}")

    def load_text(self):
        """Clear the text area."""
        def get_app_dir():
            if getattr(sys, 'frozen', False):
                return os.path.dirname(sys.executable)
            return os.path.dirname(os.path.abspath(__file__))

        app_dir = get_app_dir()
        csv_path = os.path.join(app_dir, file_csv)
        if os.path.exists(csv_path):
            self.text_area.delete("1.0", tk.END)
            with open(csv_path, "r") as f:
                for line in f:
                    self.text_area.insert(tk.END, line)

            self.message_logger.log_message('SUCCESS', "Text loaded.")
        else:
            self.message_logger.log_message('ERROR', "CSV file does not exist")

    def select_all(self, event):
        """Select all text in the text area."""
        self.text_area.tag_add(tk.SEL, "1.0", tk.END)
        return "break"