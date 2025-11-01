# RIGa&DeepSeek 26.10.2025
import tkinter as tk
from tkinter import scrolledtext
from datetime import datetime

debug = False


class MessageLogger:
    def __init__(self, log_widget: tk.scrolledtext.ScrolledText):
        self.log_widget = log_widget
        self.log_widget.configure(state='disabled')
        self.main_app = None  # Reference to main application

        # Color settings for different log levels
        self.colors = {
            'ERROR': 'red',
            'WARNING': 'orange',
            'INFO': 'black',
            'DEBUG': 'gray',
            'SUCCESS': 'green'
        }

        # Storage for the last message
        self._last_message = None
        self._last_message_id = 0

        # Bind right-click context menu and Ctrl+C
        self._setup_context_menu()

    def set_main_app(self, main_app):
        """Set reference to main application for accessing global flags"""
        self.main_app = main_app

    def _setup_context_menu(self):
        """Setup context menu for copy functionality"""
        # Create context menu
        self.context_menu = tk.Menu(self.log_widget, tearoff=0)
        self.context_menu.add_command(label="Copy", command=self._copy_selection)
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Select All", command=self._select_all)
        self.context_menu.add_command(label="Clear", command=self._clear_messages)

        # Bind right-click to show context menu
        self.log_widget.bind("<Button-3>", self._show_context_menu)  # Button-3 is right-click

        # Bind Ctrl+C and Ctrl+A
        self.log_widget.bind("<Control-c>", self._copy_selection_event)
        self.log_widget.bind("<Control-C>", self._copy_selection_event)  # Shift+Ctrl+C
        self.log_widget.bind("<Control-a>", self._select_all_event)
        self.log_widget.bind("<Control-A>", self._select_all_event)  # Shift+Ctrl+A

    def _show_context_menu(self, event):
        """Show context menu on right-click"""
        try:
            self.context_menu.tk_popup(event.x_root, event.y_root)
        finally:
            self.context_menu.grab_release()

    def _copy_selection(self):
        """Copy selected text to clipboard"""
        try:
            if self.log_widget.tag_ranges("sel"):
                # Get selected text
                selected_text = self.log_widget.get("sel.first", "sel.last")
                self.log_widget.clipboard_clear()
                self.log_widget.clipboard_append(selected_text)
        except Exception:
            # If no text is selected, do nothing
            pass

    def _copy_selection_event(self, event=None):
        """Handle Ctrl+C key binding"""
        self._copy_selection()
        return "break"  # Prevent default behavior

    def _select_all(self):
        """Select all text in the log widget"""
        self.log_widget.tag_add("sel", "1.0", "end")
        self.log_widget.mark_set("insert", "1.0")
        self.log_widget.see("1.0")

    def _select_all_event(self, event=None):
        """Handle Ctrl+A key binding"""
        self._select_all()
        return "break"  # Prevent default behavior

    def _clear_messages(self):
        """Clear all messages from the log widget"""
        self.log_widget.configure(state='normal')
        self.log_widget.delete('1.0', 'end')
        self.log_widget.configure(state='disabled')
        self._last_message = None

    def log_message(self, level: str, message: str, update_last: bool = False):
        """
        Main logging method
        :param level: Log level (error, warning, info, debug, success)
        :param message: Message text
        :param update_last: Replace last message instead of adding new
        """
        level = level.upper()
        if level not in self.colors:
            level = 'INFO'

        if debug:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            formatted_message = f"{timestamp} - {message}\n"
        else:
            formatted_message = f"{message}\n"

        self.log_widget.configure(state='normal')

        if update_last and self._last_message is not None:
            # Replace last message
            self.log_widget.delete('end-2l', 'end')
        else:
            # Add new line if not updating
            self.log_widget.insert('end', '\n')

        # Insert new message with color
        self.log_widget.insert('end', formatted_message)
        self.log_widget.tag_add(level, 'end-2l', 'end-1c')
        self.log_widget.tag_config(level, foreground=self.colors[level])

        self.log_widget.configure(state='disabled')

        # Store last message info
        self._last_message = message
        self._last_message_id += 1

        # Scroll to new message
        self.log_widget.see('end')

    def update_last_message(self, new_message: str):
        """Update text of the last logged message"""
        if self._last_message is not None:
            # Get last message tags to determine level
            tags = self.log_widget.tag_names('end-2l')
            level = 'INFO'
            for tag in tags:
                if tag in self.colors:
                    level = tag
                    break

            self.log_message(level, new_message, update_last=True)


def log(self, message):
    self.log_message('INFO', message)