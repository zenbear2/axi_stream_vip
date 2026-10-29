"""Run a simulator with a wall timeout and require a clean UVM summary."""

import argparse
import os
from pathlib import Path
import re
import signal
import subprocess
import sys


def run_test(command, log_path, timeout=30, expected_error_id=None):
    log_path = Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with subprocess.Popen(command, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, start_new_session=True) as proc:
        timed_out = False
        try:
            output, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGKILL)
            output, _ = proc.communicate()
        log_path.write_text(output)
    good = proc.returncode == 0 and not timed_out
    for severity in ("ERROR", "FATAL"):
        counts = re.findall(rf"^UVM_{severity}\s*:\s*(\d+)\s*$", output, re.MULTILINE)
        expected_count = 1 if severity == "ERROR" and expected_error_id else 0
        good &= bool(counts) and all(int(count) == expected_count for count in counts)
    if expected_error_id:
        good &= re.search(rf"^UVM_ERROR .*\[{re.escape(expected_error_id)}\]",
                          output, re.MULTILINE) is not None
    if timed_out:
        output += f"\nWall timeout after {timeout} seconds\n"
        log_path.write_text(output)
    return good, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", required=True)
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("a simulator command is required after --")
    good, output = run_test(command, args.log, args.timeout)
    sys.stdout.write(output)
    if not good:
        sys.exit(f"FAIL; see {args.log}")


if __name__ == "__main__":
    main()
