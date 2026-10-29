"""Run several payload seeds with/without an in-flight reset; check UVM reports."""

import re
from run_test import run_test


for seed in (1, 7, 42):
    for reset in (False, True):
        name = f"{'reset' if reset else 'normal'}_seed{seed}"
        cmd = ["./obj_uvm/Vuvm_top", f"+verilator+seed+{seed}",
               f"+verilator+coverage+file+logs/{name}.dat"]
        if reset:
            cmd.append("+AXIS_RESET")
        good, output = run_test(cmd, f"logs/{name}.log")
        good &= "stall=100.0% packet=100.0%" in output
        good &= ("accepted=45 compared=41 flushed=4 pending=0 resets=1" if reset
                 else "accepted=45 compared=45 flushed=0 pending=0 resets=0") in output
        if reset:
            good &= re.search(r"^UVM_INFO .*\[RETRY\] Reset interrupted", output, re.MULTILINE) is not None
        if not good:
            raise SystemExit(f"FAIL {name}; see logs/{name}.log")
        print(f"PASS {name}", flush=True)

# 正向測試之外，也確認 checker 真的會拒絕錯誤，而非永遠回報成功。
for fault, expected_id in (("none", None), ("mismatch", "MISMATCH"),
                           ("extra", "EXTRA"), ("missing", "COUNT")):
    name = f"scoreboard_{fault}"
    cmd = ["./obj_uvm/Vuvm_top", "+UVM_TESTNAME=axis_scoreboard_self_test",
           f"+SCOREBOARD_FAULT={fault}",
           f"+verilator+coverage+file+logs/{name}.dat"]
    good, output = run_test(cmd, f"logs/{name}.log", expected_error_id=expected_id)
    if not good:
        raise SystemExit(f"FAIL {name}; see logs/{name}.log")
    print(f"PASS {name}" + (" (expected error detected)" if expected_id else ""), flush=True)
