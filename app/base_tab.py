# RIGa&AI 2026 - shared tab base class
"""Common base for notebook tabs.

Provides the shared notebook frame, message logger reference, and unified
directory resolution (delegated to :mod:`paths`), removing the per-tab copies
of ``get_scripts_dir`` / ``get_data_dir`` that previously diverged.
"""

import os
from tkinter import ttk

import paths


class BaseTab:
    def __init__(self, notebook, message_logger):
        self.message_logger = message_logger
        self.notebook = notebook
        self.frame = ttk.Frame(notebook)

    # --- directory helpers (delegate to the pure `paths` module) ----------
    def get_app_root_dir(self) -> str:
        return paths.app_root_dir()

    def get_scripts_dir(self) -> str:
        return paths.scripts_dir()

    def get_data_dir(self) -> str:
        return paths.data_dir()

    # --- shared file helper -----------------------------------------------
    @staticmethod
    def _is_file_locked(filepath: str) -> bool:
        """Return True if the file exists and cannot be opened for append."""
        if not os.path.exists(filepath):
            return False
        try:
            with open(filepath, "a", encoding="utf-8"):
                pass
            return False
        except IOError:
            return True
