# 2025.10.18
import os
import time
import threading


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
            self.message_logger.log_message('WARNING', "Script is already running")
            return False

        try:
            log_file = os.path.join(self.scripts_dir, "script_safe.log")

            # Create simple script
            script_file = self._create_run_script(script_name, glob_var)

            def execute_and_monitor():
                try:
                    # Execute the script
                    self.screen_handler.execute_in_orcad(script_file, self.message_logger)

                    # Monitor log file for completion
                    result = self._monitor_log_file(log_file, timeout=300)

                    if result['success']:
                        self.message_logger.log_message('SUCCESS', f"Cable drawing completed successfully")
                    else:
                        self.message_logger.log_message('ERROR', f"Cable drawing failed or timed out")

                    if callback:
                        callback(result)

                except Exception as e:
                    self.message_logger.log_message('ERROR', f"Execution error: {str(e)}")
                    if callback:
                        callback({'success': False, 'error': str(e)})
                finally:
                    self.is_executing = False

            self.is_executing = True
            monitor_thread = threading.Thread(target=execute_and_monitor)
            monitor_thread.daemon = True
            monitor_thread.start()

            return True

        except Exception as e:
            self.message_logger.log_message('ERROR', f"Error preparing script: {str(e)}")
            self.is_executing = False
            return False

    def _create_run_script(self, script_name, glob_var):
        """Create simple TCL script for run script"""
        script_file = os.path.join(self.scripts_dir, 'run_script.tcl')
        main_script_path = os.path.join(self.scripts_dir, script_name).replace('\\', '/')
        # Build variable assignments
        var_assignments = "\n".join([f'set {var_name} "{var_value}"' for var_name, var_value in glob_var])

        # Build variable cleanup
        var_cleanup = "\n".join(
            [f'if {{[info exists {var_name}]}} {{unset {var_name}}}' for var_name, var_value in glob_var])
        script_content = f"""
set start_time [clock seconds]
puts "Start script"
{var_assignments}
if {{[catch {{source "{main_script_path}"}} err]}} {{
    puts $err
}} else {{
    puts "Script done!"
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
        for var_name, var_value in glob_var:
            script_content += f'if {{[info exists {var_name}]}} {{unset {var_name}}}\n'

        with open(script_file, 'w', encoding='utf-8') as f:
            f.write(script_content)

        return script_file

    def _monitor_log_file(self, log_file, timeout=300):
        """Monitor log file for script completion"""
        start_time = time.time()
        last_size = 0
        no_growth_count = 0

        while time.time() - start_time < timeout:
            if os.path.exists(log_file):
                try:
                    # Force read from disk (not from cache)
                    with open(log_file, 'r', encoding='utf-8') as f:
                        content = f.read()

                    current_size = len(content)

                    # Check for "Script done!" in the last line
                    lines = content.strip().split('\n')
                    if lines and "Script done!" in lines[-1]:
                        return {'success': True, 'execution_time': time.time() - start_time}

                    # Check for growth to detect hangs
                    if current_size > last_size:
                        last_size = current_size
                        no_growth_count = 0
                    else:
                        no_growth_count += 1
                        if no_growth_count >= 5:
                            return {
                                'success': False,
                                'error': 'Log file stopped growing - possible hang',
                                'execution_time': time.time() - start_time
                            }

                except Exception as e:
                    self.message_logger.log_message('WARNING', f"Error reading log file: {e}")

            time.sleep(2)

        return {
            'success': False,
            'error': f'Timeout after {timeout} seconds',
            'execution_time': time.time() - start_time
        }
