# RIGa&DeepSeek 26.10.2025
import sys
import os
import subprocess
import ctypes
import win32api
import win32con
import time

english_layout_id = 0x0409


def get_current_layout():
    """Get current keyboard layout"""
    try:
        hwnd = ctypes.windll.user32.GetForegroundWindow()
        thread_id = ctypes.windll.user32.GetWindowThreadProcessId(hwnd, 0)
        layout_id = ctypes.windll.user32.GetKeyboardLayout(thread_id)
        return layout_id & 0xFFFF
    except:
        return english_layout_id


def set_english_layout():
    """Switch to English layout using multiple methods"""
    try:
        # Method 1: Broadcast message to all windows
        win32api.SendMessage(
            win32con.HWND_BROADCAST,
            win32con.WM_INPUTLANGCHANGEREQUEST,
            0,
            english_layout_id,
        )

        # Method 2: Direct activation
        layout_handle = ctypes.windll.user32.LoadKeyboardLayoutW("00000409", 0)
        ctypes.windll.user32.ActivateKeyboardLayout(layout_handle, 0)

        # Method 3: Alternative approach
        win32api.SendMessage(
            win32con.HWND_BROADCAST,
            win32con.WM_INPUTLANGCHANGEREQUEST,
            1,  # INPUTLANGCHANGE_SYSCHARSET
            english_layout_id,
        )

        return True
    except Exception as e:
        print(f"Layout switch error: {e}")
        return False


def ensure_caps_lock_off():
    """Ensure Caps Lock is off"""
    try:
        caps_lock_state = win32api.GetKeyState(win32con.VK_CAPITAL)
        if caps_lock_state & 0x0001:
            win32api.keybd_event(
                win32con.VK_CAPITAL, 0, win32con.KEYEVENTF_EXTENDEDKEY, 0
            )
            win32api.keybd_event(
                win32con.VK_CAPITAL,
                0,
                win32con.KEYEVENTF_EXTENDEDKEY | win32con.KEYEVENTF_KEYUP,
                0,
            )
            return True
        return False
    except:
        return False


def launch_main_app():
    """Launch main application"""
    if getattr(sys, "frozen", False):
        # Running as executable - find main app in same directory
        app_dir = os.path.dirname(sys.executable)
        main_app = os.path.join(app_dir, "cable_automation.exe")
    else:
        # Running as script
        app_dir = os.path.dirname(os.path.abspath(__file__))
        main_app = os.path.join(app_dir, "cable_automation.py")  # Изменили имя

    if os.path.exists(main_app):
        try:
            if getattr(sys, "frozen", False):
                subprocess.Popen([main_app])
            else:
                python = sys.executable
                subprocess.Popen([python, main_app])
            return True
        except Exception as e:
            print(f"Failed to launch main application: {e}")
            return False
    else:
        print(f"Main application not found at: {main_app}")
        return False


def main():
    """Main function"""
    # Ensure Caps Lock is off
    ensure_caps_lock_off()

    # Check current layout
    current_layout = get_current_layout()
    print(f"Current layout: {hex(current_layout)}")

    # Switch to English if needed
    if current_layout != english_layout_id:
        print("Switching to English layout...")
        set_english_layout()

        # Wait for layout change to take effect
        time.sleep(1)

        # Verify layout change
        new_layout = get_current_layout()
        print(f"New layout: {hex(new_layout)}")

    # Launch main application
    print("Launching main application...")
    launch_main_app()


if __name__ == "__main__":
    main()
