# 2025.10.18
# pip install pyautogui pywin32 openpyxl
import tkinter as tk
from tkinter import ttk
from tkinter import scrolledtext

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

        # Simple layout check (just for logging)
        screen_handler = ScreenHandler(self.message_logger)
        current_layout = screen_handler.get_current_layout()

        if current_layout == english_layout_id:
            self.message_logger.log_message('INFO', 'English keyboard layout confirmed')
        else:
            self.message_logger.log_message('WARNING', f'Non-English layout detected: {hex(current_layout)}')

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