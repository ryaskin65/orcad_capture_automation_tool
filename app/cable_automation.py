# RIGa&DeepSeek 16.01.2026
# pip install pyautogui pywin32 openpyxl
import tkinter as tk
from tkinter import ttk
from tkinter import scrolledtext

try:
    from message_logger import MessageLogger
    from cable_automation_tab import CableAutomationTab
    from find_and_replace_tab import FindAndReplaceTab
    from offpage_tab import OffPageTab
    from copy_xy_text_tab import CopyXYTextTab
    from copy_text_tab import CopyTextTab
    from screen_handler import ScreenHandler, english_layout_id
except ImportError as e:
    print(f"Import error: {e}")
    raise


class MainApp:
    def __init__(self, root):
        self.root = root
        self.root.title("OrCAD Capture Automation Tool, RIGa&AI 16.01.2026")
        self.root.geometry("800x600")

        # Global flag for non-English layout
        self.non_english_layout_detected = False

        # Create notebook for tabs
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(pady=10, padx=10, fill="both", expand=True)

        # Message area at the bottom
        self.log_widget = scrolledtext.ScrolledText(root, height=10)
        self.log_widget.pack(side="bottom", fill="x")
        self.message_logger = MessageLogger(self.log_widget)

        # Set reference to main app for message logger
        self.message_logger.set_main_app(self)

        # Check keyboard layout and set global flag
        self.check_keyboard_layout()

        # Initialize tabs only if English layout is active
        if not self.non_english_layout_detected:
            try:
                self.cable_automation_tab = CableAutomationTab(
                    self.notebook, self.message_logger
                )
                self.find_and_replace_tab = FindAndReplaceTab(
                    self.notebook, self.message_logger
                )
                self.offpage_tab = OffPageTab(self.notebook, self.message_logger)
                self.copy_xy_text_tab = CopyXYTextTab(
                    self.notebook, self.message_logger
                )
                self.copy_text_tab = CopyTextTab(self.notebook, self.message_logger)
            except NameError as e:
                self.message_logger.log_message(
                    "ERROR", f"Error initializing tabs: {e}"
                )
                raise

            # Add tabs to notebook
            self.notebook.add(
                self.cable_automation_tab.frame, text=" Cable Automation "
            )
            self.notebook.add(
                self.find_and_replace_tab.frame, text=" Find & replace text "
            )
            self.notebook.add(self.offpage_tab.frame, text=" Connectors & Ports ")
            self.notebook.add(self.copy_xy_text_tab.frame, text=" Copy X, Y, Text ")
            self.notebook.add(self.copy_text_tab.frame, text=" Copy Text ")
        else:
            # Show warning message in the notebook area
            warning_frame = tk.Frame(self.notebook)
            warning_frame.pack(fill="both", expand=True, padx=20, pady=20)

            warning_label = tk.Label(
                warning_frame,
                text="Application requires English keyboard layout\n\nPlease restart the application after layout change",
                font=("Arial", 12, "bold"),
                fg="red",
                justify="center",
            )
            warning_label.pack(expand=True)

            self.notebook.add(warning_frame, text="Warning")

        # Bind window close
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def check_keyboard_layout(self):
        """Check keyboard layout and set global flag"""
        screen_handler = ScreenHandler(self.message_logger)
        current_layout = screen_handler.get_current_layout()

        if current_layout == english_layout_id:
            self.non_english_layout_detected = False
        else:
            self.message_logger.log_message(
                "WARNING", f"Non-English layout detected: {hex(current_layout)}"
            )
            self.message_logger.log_message(
                "WARNING", "Program must run with English keyboard layout only"
            )

            # Try to switch to English layout
            if screen_handler.set_english_layout_safe():
                self.message_logger.log_message(
                    "INFO", "Layout switched to English automatically"
                )
                self.message_logger.log_message(
                    "INFO", "Please RESTART the application for proper operation"
                )
            else:
                self.message_logger.log_message(
                    "ERROR", "Failed to switch to English layout"
                )

            self.non_english_layout_detected = True

    def on_close(self):
        """Handle window close."""
        self.root.quit()
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = MainApp(root)
    root.mainloop()
