#!/usr/bin/env python3
"""Expose installed libz3's SMT-LIB evaluator over stdin/stdout.

Used only when the z3 command is unavailable. All solving is performed by Z3.
Verilator's generated SMT-LIB commands are newline terminated.
"""

import ctypes
import ctypes.util
import sys


def main():
    path = ctypes.util.find_library("z3")
    if path is None:
        sys.exit("Install z3 (sudo apt install z3) or provide VERILATOR_SOLVER")
    z3 = ctypes.CDLL(path)
    z3.Z3_mk_config.restype = ctypes.c_void_p
    z3.Z3_del_config.argtypes = [ctypes.c_void_p]
    z3.Z3_set_param_value.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    z3.Z3_mk_context.argtypes = [ctypes.c_void_p]
    z3.Z3_mk_context.restype = ctypes.c_void_p
    z3.Z3_del_context.argtypes = [ctypes.c_void_p]
    z3.Z3_eval_smtlib2_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    z3.Z3_eval_smtlib2_string.restype = ctypes.c_char_p

    def new_context():
        config = z3.Z3_mk_config()
        z3.Z3_set_param_value(config, b"unsat_core", b"true")
        context = z3.Z3_mk_context(config)
        z3.Z3_del_config(config)
        return context

    context = new_context()
    # Buffer complete S-expressions, allowing multiline commands and strings.
    command = []
    depth = 0
    quoted = False
    assumptions = "()"
    try:
        for line in sys.stdin:
            command.append(line)
            for ch in line:
                if ch == '"':
                    quoted = not quoted
                elif not quoted:
                    if ch == ";":
                        break
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
            if depth != 0 or quoted:
                continue
            text = "".join(command)
            command.clear()
            if text.strip() == "(exit)":
                return
            if text.strip() == "(reset)":
                # Older libz3 retains initialization-only options across reset.
                # A fresh context restores the CLI's fresh-session semantics.
                z3.Z3_del_context(context)
                context = new_context()
                assumptions = "()"
                continue
            if text.strip() in {"(set-option :produce-unsat-assumptions true)",
                                "(set-option :produce-unsat-cores true)"}:
                # C API config enables cores before context initialization.
                continue
            if text.strip() == "(get-unsat-assumptions)":
                # All original assumptions form a valid (nonminimal) core
                # after UNSAT. Older C API evaluators cannot enable this CLI
                # option, so retain the original list instead of minimizing it.
                print(assumptions, flush=True)
                continue
            if text.strip().startswith("(check-sat-assuming "):
                assumptions = text.strip()[len("(check-sat-assuming "):-1]
            result = z3.Z3_eval_smtlib2_string(context, text.encode())
            if result:
                sys.stdout.write(result.decode())
                sys.stdout.flush()
        if command:
            sys.exit("Incomplete SMT-LIB command")
    finally:
        z3.Z3_del_context(context)


if __name__ == "__main__":
    main()
