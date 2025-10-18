# 2025.10.18
# pip install pyautogui pywin32 openpyxl
import tkinter as tk
from tkinter import ttk
from tkinter import scrolledtext
import sys
import subprocess

try:
    from message_logger import MessageLogger
    from cable_draw_tab import CableDraw
    from simple_replace_tab import SimpleReplaceTab
    from offpage_tab import OffPageTab
    from copy_text_tab import CopyTextTab
    from screen_handler import ScreenHandler, english_layout_id
except ImportError as e:
    print(f"Import error: {e}")
    raise


class LayoutChecker:
    def __init__(self, message_logger):
        self.screen_handler = ScreenHandler(message_logger)
        self.english_layout_id = english_layout_id
        self.message_logger = message_logger

    def is_english_layout(self):
        """Check if current layout is English"""
        current_layout = self.screen_handler.get_current_layout()
        return current_layout == self.english_layout_id

    def check_and_restart_if_needed(self):
        """Check layout and restart if needed - returns True if restart was performed"""
        if not self.is_english_layout():
            # Switch to English layout
            self.screen_handler.set_english_layout_safe()

            # Restart application with restart flag
            self._restart_application()
            return True
        return False

    def _restart_application(self):
        """Restart the current application with restart flag"""
        python = sys.executable
        script = sys.argv[0]
        # Add restart flag to arguments
        args = [python, script, "--layout-switched"]
        subprocess.Popen(args)
        sys.exit(0)


class MainApp:
    def __init__(self, root):
        self.root = root
        self.root.title("OrCAD Capture Cable Automation Tool, 2025.10.18")
        self.root.geometry("800x600")

        # Create notebook for tabs
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(pady=10, padx=10, fill="both", expand=True)

        # Message area at the bottom
        self.log_widget = scrolledtext.ScrolledText(root, height=10)
        self.log_widget.pack(side='bottom', fill='x')
        self.message_logger = MessageLogger(self.log_widget)

        # Check if application was restarted due to layout switch
        layout_was_switched = "--layout-switched" in sys.argv

        # Check keyboard layout
        layout_checker = LayoutChecker(self.message_logger)

        if layout_was_switched:
            # This is a restart after layout switch
            self.message_logger.log_message('INFO', 'Keyboard layout switched to English')
        else:
            # This is first run - check if restart is needed
            restart_performed = layout_checker.check_and_restart_if_needed()
            # If no restart was performed and we're still here, layout was already English
            if not restart_performed:
                # Don't show confirmation message for already English layout
                pass

        # Initialize tabs
        try:
            self.cable_draw_tab = CableDraw(self.notebook, self.message_logger)
            self.simple_replace_tab = SimpleReplaceTab(self.notebook, self.message_logger)
            self.offpage_tab = OffPageTab(self.notebook, self.message_logger)
            self.copy_text_tab = CopyTextTab(self.notebook, self.message_logger)
        except NameError as e:
            self.message_logger.log_message(f"Error initializing tabs: {e}")
            raise

        # Add tabs to notebook
        self.notebook.add(self.cable_draw_tab.frame, text="Cable Automation")
        self.notebook.add(self.simple_replace_tab.frame, text="Find & replace text")
        self.notebook.add(self.offpage_tab.frame, text="Connectors")
        self.notebook.add(self.copy_text_tab.frame, text="Copy Text")

        # Bind window close
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def on_close(self):
        """Handle window close."""
        self.root.quit()
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = MainApp(root)
    root.mainloop()