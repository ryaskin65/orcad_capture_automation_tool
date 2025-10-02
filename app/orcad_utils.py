import tkinter as tk
from tkinter import ttk
from tkinter import scrolledtext

try:
    from message_logger import MessageLogger
    from simple_replace_tab import SimpleReplaceTab
    from complex_replace_tab import ComplexReplaceTab
    from cable_draw_tab import CableDraw
    from copy_text_tab import CopyTextTab
    from offpage_tab import OffPageTab
except ImportError as e:
    print(f"Import error: {e}")
    raise


class MainApp:
    def __init__(self, root):
        self.root = root
        self.root.title("OrCAD Capture Utility, 2025.07.11")
        self.root.geometry("800x600")

        # Create notebook for tabs
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(pady=10, padx=10, fill="both", expand=True)

        # Message area at the bottom
        self.log_widget = scrolledtext.ScrolledText(root, height=10)
        self.log_widget.pack(side='bottom', fill='x')
        self.message_logger = MessageLogger(self.log_widget)

        # Initialize tabs
        try:
            self.simple_replace_tab = SimpleReplaceTab(self.notebook, self.message_logger)
            self.table_tab = ComplexReplaceTab(self.notebook, self.message_logger)
            self.cable_draw_tab = CableDraw(self.notebook, self.message_logger)
            self.copy_text_tab = CopyTextTab(self.notebook, self.message_logger)
            self.offpage_tab = OffPageTab(self.notebook, self.message_logger)
        except NameError as e:
            self.message_logger.log_message(f"Error initializing tabs: {e}")
            raise

        # Add tabs to notebook
        self.notebook.add(self.simple_replace_tab.frame, text="Simple Replace")
        self.notebook.add(self.table_tab.frame, text="Complex Replace")
        self.notebook.add(self.cable_draw_tab.frame, text="Cable Draw")
        self.notebook.add(self.copy_text_tab.frame, text="Copy Text")
        self.notebook.add(self.offpage_tab.frame, text="OffPage")

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