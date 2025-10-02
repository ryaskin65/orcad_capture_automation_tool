import tkinter as tk
from tkinter import scrolledtext
from datetime import datetime

debug = False

class MessageLogger:
    def __init__(self, log_widget: tk.scrolledtext.ScrolledText):
        self.log_widget = log_widget
        self.log_widget.configure(state='disabled')

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