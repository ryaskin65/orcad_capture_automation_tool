# from pywinauto import Application
# # Подключаемся к уже запущенному OrCAD Capture
# app = Application(backend="uia").connect(class_name="OrCaptureFrame")
# # Выводим структуру элементов для анализа
# app.window(class_name="OrCaptureFrame").print_control_identifiers(depth=3)

import pyautogui
import time
import win32api
import ctypes
import win32gui
import win32con


english_layout_id = 0x0409

class ScreenHandler:
    def __init__(self, message_logger):
        self.message_logger = message_logger
        # Move mouse to upper-left corner to abort
        pyautogui.FAILSAFE = True
        pyautogui.PAUSE = 0.1  # Small pause between actions

    def get_current_layout(self):
        hwnd = ctypes.windll.user32.GetForegroundWindow()
        thread_id = ctypes.windll.user32.GetWindowThreadProcessId(hwnd, 0)
        layout_id = ctypes.windll.user32.GetKeyboardLayout(thread_id)
        return layout_id & 0xFFFF

    # eng 0x0409
    def set_keyboard_layout(self, layout_id):
        win32api.SendMessage(
            win32con.HWND_BROADCAST,
            win32con.WM_INPUTLANGCHANGEREQUEST,
            None,
            layout_id
        )

    def ensure_caps_lock_off(self):
        caps_lock_state = win32api.GetKeyState(win32con.VK_CAPITAL)
        if caps_lock_state & 0x0001:
            win32api.keybd_event(win32con.VK_CAPITAL, 0, win32con.KEYEVENTF_EXTENDEDKEY, 0)
            win32api.keybd_event(win32con.VK_CAPITAL, 0, win32con.KEYEVENTF_EXTENDEDKEY | win32con.KEYEVENTF_KEYUP, 0)
            return True
        return False

    def set_english_layout_safe(self):
        self.ensure_caps_lock_off()
        if not (self.get_current_layout() == english_layout_id):
            self.set_keyboard_layout(english_layout_id)

    def find_largest_visible_window(self, main_hwnd, target_class):
        """Find the largest visible window of a specific class among child windows."""
        instances = []

        def enum_callback(hwnd, lparam):
            if win32gui.GetClassName(hwnd) == target_class and win32gui.IsWindowVisible(hwnd):
                instances.append(hwnd)
            return True

        win32gui.EnumChildWindows(main_hwnd, enum_callback, None)

        if not instances:
            return None, 0

        max_area = 0
        target_hwnd = None
        for hwnd in instances:
            rect = win32gui.GetWindowRect(hwnd)
            area = (rect[2] - rect[0]) * (rect[3] - rect[1])
            if area > max_area:
                max_area = area
                target_hwnd = hwnd

        return target_hwnd, max_area

    def click_window_center(self, hwnd):
        """Click the center of a window."""
        rect = win32gui.GetWindowRect(hwnd)
        x = (rect[0] + rect[2]) // 2
        y = (rect[1] + rect[3]) // 2
        pyautogui.click(x, y)

    def click_window_left_top(self, hwnd):
        """Click the center of a window."""
        rect = win32gui.GetWindowRect(hwnd)
        x = rect[0] + 10
        y = rect[1] + 10
        pyautogui.click(x, y)

    def execute_in_orcad(self, script_path, message_logger, wait_and_clic=0):
        """Execute the source command in OrCAD Capture command window."""
        self.set_english_layout_safe()

        main_hwnd = win32gui.FindWindow("OrCaptureFrame", None)
        if not main_hwnd:
            self.message_logger.log_message('ERROR', "The OrCAD window was not found!")
            return False

        # Find command window (Edit class)
        edit_hwnd, area = self.find_largest_visible_window(main_hwnd, "Edit")
        if not edit_hwnd or area < 10000:
            self.message_logger.log_message('ERROR', "Command Window not found! (Menu: View -> Command Window)")
            return False

        # Activate and interact with command window
        win32gui.SetForegroundWindow(main_hwnd)
        time.sleep(0.3)
        self.click_window_center(edit_hwnd)
        time.sleep(0.5)

        # Clear command window and execute command
        pyautogui.write("cls\n")
        time.sleep(0.5)
        # # pyautogui.write(f'set ::find_text "{find_text}"\n')
        # pyautogui.write(f'set ::find_text 22\n')
        # time.sleep(0.5)
        # # pyautogui.write(f'set ::replace_text "{replace_text}"\n')
        # pyautogui.write(f'set ::replace_text 20\n')
        # time.sleep(0.5)
        # # pyautogui.write(f'set ::scope "{scope}"\n')

        # Type the source command and press Enter
        script_path = script_path.replace('\\', '/')
        command = f'source "{script_path}"'
        pyautogui.write(command)
        pyautogui.press('enter')
        time.sleep(2)

        # Find and click OrRandomView window
        if wait_and_clic > 0:
            time.sleep(wait_and_clic)
            view_hwnd, area = self.find_largest_visible_window(main_hwnd, "OrRandomView")
            if view_hwnd and area > 10000:
                win32gui.SetForegroundWindow(main_hwnd)
                time.sleep(0.3)
                self.click_window_left_top(view_hwnd)

        self.message_logger.log_message('SUCCESS', f"Executed command: {command}")
        return True
