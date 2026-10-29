# AXI Stream UVM Learning Project

以簡單 AXI Stream FIFO 學習 SystemVerilog 與 UVM：從 transaction、sequence、driver、monitor，逐步建立 agent、environment、scoreboard 與 functional coverage。

目前設定為 32-bit data、`tkeep=4'b1111`、FIFO 深度 4。這是一個教學專案，已測試範圍與限制見 [TEST_REVIEW.md](TEST_REVIEW.md)。

## 架構

```text
axis_random_seq → source.seqr → source.drv → s_axis → FIFO → m_axis
                                              ↓               ↓
                                         source.mon       output_mon
                                              └── scoreboard ──┘
                                                              └── coverage
```

`axis_env` 組裝 source agent、輸出 monitor、scoreboard 與 coverage。driver 包含 source BFM 時序；sink 的 backpressure 由 top 控制。

## 環境需求

- SystemVerilog 編譯器：已驗證 Verilator 5.052。
- UVM library：已驗證 Accellera UVM 2020.3.1；需另外下載，不包含在此 repository。
- GNU Make、支援 coroutines 的 C++ 編譯器（已驗證 GCC 11.4）、Python 3。
- Z3 solver。若只有 `libz3` shared library，Makefile 可使用 `tools/z3_stdio.py` 作為目前測試所需的 SMT 入口；擴展複雜 constraints 時建議使用完整 z3 執行檔。

## 執行

指定你本機的 UVM library 路徑（應包含 `src/uvm_pkg.sv`）：

```bash
export UVM_HOME="$HOME/tools/uvm-2020.3.1"
make build VERILATOR=verilator
make run VERILATOR=verilator
make reset VERILATOR=verilator
make regression VERILATOR=verilator
```

`UVM_HOME` 也可以直接傳入 make：

```bash
make regression UVM_HOME=/path/to/uvm-2020.3.1 VERILATOR=verilator
```

調整 seed、建立波形：

```bash
make reset VERILATOR=verilator SEED=7 RUN_ARGS=+AXIS_TRACE
```

- log 與 regression coverage database：`logs/`。
- 波形：`uvm_axis.vcd`。
- 單次測試同時檢查模擬器退出碼與 UVM error/fatal 摘要，並設有 wall timeout。
- 回歸包含六個 FIFO 測試與四個 scoreboard self-test。反向 self-test 必須抓到預期 error 才算通過。

## Reset 約定

受控 reset 情境會在 FIFO 已滿、source 確實等待握手時清除四筆 pending beat；未握手的 beat 於 reset 後重送。FIFO 不保證 packet 原子性，reset 可截斷 packet。

## 學習文件

- [逐步練習指南](UVM_AXIS_STEP_BY_STEP.md)
- [STEP 9 架構與檔案責任](STEP9_ARCHITECTURE.md)
- [測試檢查紀錄與限制](TEST_REVIEW.md)

原始 `tb.sv`、`axis_basic_seq.sv` 與 `axis_checker.sv` 保留作為前期練習參考。編譯產物、波形、log 與本機工具不納入版本控制。
