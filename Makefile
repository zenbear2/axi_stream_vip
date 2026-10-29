UVM_HOME ?= /home/user/tools/uvm-2020.3.1
VERILATOR ?= /usr/local/bin/verilator
JOBS ?= 2
SEED ?= 1
RUN_ARGS ?=
BUILD_DIR := obj_uvm
BIN := $(BUILD_DIR)/Vuvm_top
SOURCES := $(wildcard axis_*.sv tests/*.sv) uvm_smoke.sv

# Prefer a real solver command; fall back to the installed Z3 shared library.
ifeq ($(origin VERILATOR_SOLVER),undefined)
ifneq ($(shell command -v z3 2>/dev/null),)
export VERILATOR_SOLVER := z3 --in -smt2
else
export VERILATOR_SOLVER := python3 $(CURDIR)/tools/z3_stdio.py
endif
endif

.PHONY: build run reset regression
build: $(BIN)

$(BIN): $(SOURCES) Makefile $(UVM_HOME)/src/uvm_pkg.sv
	$(VERILATOR) --binary --timing --assert --trace --coverage-user \
	  -j $(JOBS) -Wno-fatal -MAKEFLAGS 'OBJCACHE=' \
	  +define+UVM_NO_DPI +incdir+$(UVM_HOME)/src +incdir+. \
	  --top-module uvm_top --Mdir $(BUILD_DIR) \
	  $(UVM_HOME)/src/uvm_pkg.sv axis_if.sv axis_fifo.sv uvm_smoke.sv

run: build
	python3 tools/run_test.py --log logs/run.log -- ./$(BIN) +verilator+seed+$(SEED) +verilator+coverage+file+coverage_normal.dat $(RUN_ARGS)

reset: build
	python3 tools/run_test.py --log logs/reset.log -- ./$(BIN) +verilator+seed+$(SEED) +AXIS_RESET +verilator+coverage+file+coverage_reset.dat $(RUN_ARGS)

regression: build
	mkdir -p logs
	python3 tools/run_regression.py
