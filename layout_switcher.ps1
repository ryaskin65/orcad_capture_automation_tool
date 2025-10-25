using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace LayoutSwitcher
{
    class Program
    {
        private const int ENGLISH_LAYOUT = 0x0409;
        private const int WM_INPUTLANGCHANGEREQUEST = 0x0050;
        private const int HWND_BROADCAST = 0xFFFF;
        private const int VK_CAPITAL = 0x14;
        private const int KEYEVENTF_EXTENDEDKEY = 0x1;
        private const int KEYEVENTF_KEYUP = 0x2;

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr ProcessId);

        [DllImport("user32.dll")]
        private static extern IntPtr GetKeyboardLayout(uint idThread);

        [DllImport("user32.dll")]
        private static extern bool PostMessage(int hWnd, uint Msg, int wParam, int lParam);

        [DllImport("user32.dll")]
        private static extern short GetKeyState(int nVirtKey);

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

        static void Main(string[] args)
        {
            Console.WriteLine("Keyboard Layout Switcher");
            
            // Disable Caps Lock
            if (DisableCapsLock())
            {
                Console.WriteLine("Caps Lock turned off");
            }

            // Check and switch layout
            int currentLayout = GetCurrentLayout();
            Console.WriteLine($"Current layout: 0x{currentLayout:X4}");

            if (currentLayout != ENGLISH_LAYOUT)
            {
                Console.WriteLine("Switching to English layout...");
                if (SetEnglishLayout())
                {
                    Thread.Sleep(500);
                    int newLayout = GetCurrentLayout();
                    Console.WriteLine($"New layout: 0x{newLayout:X4}");
                }
                else
                {
                    Console.WriteLine("Failed to switch layout");
                }
            }
            else
            {
                Console.WriteLine("English layout confirmed");
            }

            // Launch main application
            Console.WriteLine("Starting main application...");
            LaunchMainApp();
        }

        static int GetCurrentLayout()
        {
            try
            {
                IntPtr hwnd = GetForegroundWindow();
                uint threadId = GetWindowThreadProcessId(hwnd, IntPtr.Zero);
                IntPtr layout = GetKeyboardLayout(threadId);
                return (int)(layout.ToInt64() & 0xFFFF);
            }
            catch
            {
                return ENGLISH_LAYOUT;
            }
        }

        static bool SetEnglishLayout()
        {
            try
            {
                return PostMessage(HWND_BROADCAST, WM_INPUTLANGCHANGEREQUEST, 0, ENGLISH_LAYOUT);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Layout switch error: {ex.Message}");
                return false;
            }
        }

        static bool DisableCapsLock()
        {
            try
            {
                short capsState = GetKeyState(VK_CAPITAL);
                if ((capsState & 0x0001) != 0)
                {
                    keybd_event((byte)VK_CAPITAL, 0, KEYEVENTF_EXTENDEDKEY, 0);
                    keybd_event((byte)VK_CAPITAL, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
                    return true;
                }
                return false;
            }
            catch
            {
                return false;
            }
        }

        static void LaunchMainApp()
        {
            string mainApp = "cable_automation.exe";
            string appPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, mainApp);

            if (File.Exists(appPath))
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = appPath,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to launch main application: {ex.Message}");
                }
            }
            else
            {
                Console.WriteLine($"Main application not found: {appPath}");
            }
        }
    }
}