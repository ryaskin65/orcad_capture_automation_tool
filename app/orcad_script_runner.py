# RIGa&DeepSeek 26.10.2025
import os
import time
import threading

CHANGE_LOG_TIMEOUT = 4


class OrcadScriptRunner:
    """Handles OrCAD script execution and monitoring with log file analysis only"""

    def __init__(self, screen_handler, message_logger, scripts_dir):
        self.screen_handler = screen_handler
        self.message_logger = message_logger
        self.scripts_dir = scripts_dir
        self.is_executing = False

    def execute_script(self, script_name, glob_var, callback=None):
        """
        Execute run script in OrCAD with log file monitoring
        """
        if self.is_executing:
            self.message_logger.log_message("WARNING", "Script is already running")
            return False

        try:
            log_file = os.path.join(self.scripts_dir, "script_safe.log")

            # Get log file modification time before execution
            log_exists_before = os.path.exists(log_file)
            log_mtime_before = os.path.getmtime(log_file) if log_exists_before else 0

            # Create simple script
            script_file = self._create_run_script(script_name, glob_var)

            def execute_and_monitor():
                try:
                    # Execute the script and check if OrCAD window was found
                    orcad_found = self.screen_handler.execute_in_orcad(
                        script_file, self.message_logger
                    )

                    if not orcad_found:
                        # Error message already logged in screen_handler.execute_in_orcad
                        if callback:
                            callback(
                                {"success": False, "error": "OrCAD window not found"}
                            )
                        return

                    # Monitor log file for completion (only check new log entries)
                    result = self._monitor_log_file(log_file, log_mtime_before)

                    if not result["success"]:
                        self.message_logger.log_message(
                            "ERROR", f"Script failed or timed out"
                        )

                    if callback:
                        callback(result)

                except Exception as e:
                    self.message_logger.log_message(
                        "ERROR", f"Execution error: {str(e)}"
                    )
                    if callback:
                        callback({"success": False, "error": str(e)})
                finally:
                    self.is_executing = False

            self.is_executing = True
            monitor_thread = threading.Thread(target=execute_and_monitor)
            monitor_thread.daemon = True
            monitor_thread.start()

            return True

        except Exception as e:
            self.message_logger.log_message(
                "ERROR", f"Error preparing script: {str(e)}"
            )
            self.is_executing = False
            return False

    def _create_run_script(self, script_name, glob_var):
        """Create simple TCL script for run script"""
        script_file = os.path.join(self.scripts_dir, "run_script.tcl")
        main_script_path = os.path.join(self.scripts_dir, script_name).replace(
            "\\", "/"
        )
        # Build variable assignments
        var_assignments = "\n".join(
            [f'set {var_name} "{var_value}"' for var_name, var_value in glob_var]
        )

        # Build variable cleanup
        var_cleanup = "\n".join(
            [
                f"if {{[info exists {var_name}]}} {{unset {var_name}}}"
                for var_name, var_value in glob_var
            ]
        )
        script_content = f"""
set start_time [clock seconds]
{var_assignments}
if {{[catch {{source "{main_script_path}"}} err]}} {{
    puts $err
}} else {{
    set end_time [clock seconds]
    set execution_time [expr {{$end_time - $start_time}}]
    puts "EXECUTION_TIME:$execution_time sec"
}}
set safeVars {{start_time end_time execution_time err}}
foreach var $safeVars {{
    if {{[info exists $var]}} {{unset $var}}
}}
{var_cleanup}
"""

        with open(script_file, "w", encoding="utf-8") as f:
            f.write(script_content)

        return script_file

    def _monitor_log_file(self, log_file, log_mtime_before):
        """
        Monitor log file for script completion with real-time log output
        """
        start_time = time.time()
        last_size = 0
        last_read_position = 0
        last_growth_time = start_time

        while time.time() - last_growth_time < CHANGE_LOG_TIMEOUT:
            if os.path.exists(log_file):
                try:
                    current_mtime = os.path.getmtime(log_file)

                    if current_mtime <= log_mtime_before:
                        time.sleep(2)
                        continue

                    current_size = os.path.getsize(log_file)
                    if current_size < last_read_position:
                        last_read_position = 0

                    with open(log_file, "r", encoding="utf-8") as f:
                        f.seek(last_read_position)
                        new_content = f.read()
                        last_read_position = f.tell()

                    if new_content.strip():
                        for line in new_content.split("\n\r"):
                            line = line.strip()
                            if line:
                                self.message_logger.log_message("INFO", line)

                    if "Script done!" in new_content:
                        execution_time = None
                        for line in new_content.split("\n"):
                            if "EXECUTION_TIME:" in line:
                                try:
                                    execution_time = line.split("EXECUTION_TIME:")[
                                        1
                                    ].split(" ")[0]
                                except:
                                    pass
                                break
                        return {
                            "success": True,
                            "execution_time": execution_time
                            or (time.time() - start_time),
                        }

                    if current_size > last_size:
                        last_size = current_size
                        last_growth_time = time.time()

                except Exception as e:
                    self.message_logger.log_message(
                        "WARNING", f"Error reading log file: {e}"
                    )

            time.sleep(1)

        return {
            "success": False,
            "error": "Log file stopped growing - possible hang",
            "execution_time": time.time() - start_time,
        }
