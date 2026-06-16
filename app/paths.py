# RIGa&AI 2026 - centralized path resolution
"""Single source of truth for project directory layout.

The Python application lives in ``app/`` and resolves the sibling
``scripts/`` and ``data/`` folders relative to the repository root. When
frozen (PyInstaller), everything is resolved relative to the executable.

This module has no GUI dependencies on purpose, so the path logic can be
unit-tested without tkinter or OrCAD.
"""

import os
import sys


def app_root_dir() -> str:
    """Return the project root directory.

    - Frozen build: the directory containing the executable.
    - Source build: the parent of the ``app/`` directory (i.e. repo root).
    """
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    # This file lives in app/, so the repo root is its grandparent directory.
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def scripts_dir() -> str:
    """Return the absolute path to the ``scripts/`` directory."""
    return os.path.join(app_root_dir(), "scripts")


def data_dir() -> str:
    """Return the absolute path to the ``data/`` directory."""
    return os.path.join(app_root_dir(), "data")


def script_path(filename: str) -> str:
    """Return the absolute path to a script file inside ``scripts/``."""
    return os.path.join(scripts_dir(), filename)


def data_path(filename: str) -> str:
    """Return the absolute path to a data file inside ``data/``."""
    return os.path.join(data_dir(), filename)
