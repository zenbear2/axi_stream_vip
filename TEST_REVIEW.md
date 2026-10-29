# 整體測試檢查紀錄

檢查日期：2026-10-28。環境：Verilator 5.052、UVM 2020.3.1。

## 發現並修正

| 問題 | 影響 | 修正位置／方式 |
| --- | --- | --- |
| `_axis.tready` 拼字錯誤 | 現行程式無法編譯 | `uvm_smoke.sv` 改回 `m_axis.tready` |
| 單次執行只看模擬器退出碼 | UVM_ERROR／UVM_FATAL 仍可能以退出碼 0 結束，導致 make 誤判成功 | `tools/run_test.py` 檢查 UVM 摘要，Makefile 的 run/reset 共用此執行器 |
| 只有模擬時間 timeout | solver 或模擬器卡住時，模擬時間可能不前進 | 執行器加入 30 秒 wall timeout，逾時終止整個測試 process group |
| Reset 以組合訊號條件觸發 | 可能在上一筆剛握手、ready 因 FIFO 變滿而下降時觸發，並未測到未握手資料的重送 | `uvm_smoke.sv` 改為上升緣確認 stall，且測試要求 driver 實際重送一次 |
| Driver 等 ready 時只在上升緣察覺 reset | 真正 stalled 的 beat 遇到 reset 時，valid 清除太晚 | `axis_driver.sv` 同時等待 clock 上升緣與 reset 下降緣；reset 時清 valid，解除後重送 |
| Monitor 的 stall 累計只在 clock 上升緣清除 | clock 間的 reset 可能讓舊的等待週期混入新資料 | `axis_monitor.sv` 同步監聽 reset 下降緣 |
| 缺少 reset 期間 valid 的檢查 | 原本 stall assertion 在 reset 期間停用，無法發現 valid 沒有拉低 | `axis_if.sv` 加入 reset 期間上升緣要求 valid=0 的 assertion |

另將 sink 排程變數的初始化獨立為敘述，移除專案自身的 IMPLICITSTATIC warning。

## 已完成的驗證

執行 `make regression`，以下十個案例全部通過驗收：

| 類別 | 案例 | 驗收結果 |
| --- | --- | --- |
| FIFO 一般測試 | seed 1、7、42 | 每次 45 筆輸入／45 筆輸出，pending=0，零 error/fatal |
| FIFO reset 測試 | seed 1、7、42 | 每次 45 筆輸入／41 筆輸出，reset 清除 4 筆，實際 retry 一次，pending=0，零 error/fatal |
| Scoreboard 正向 self-test | 正確的三筆資料，輸入物件在 write 後另行修改 | 仍正確比對，確認預期值有獨立複製 |
| Scoreboard 反向 self-test | 改錯一筆 data | 必須出現一個 MISMATCH error |
| Scoreboard 反向 self-test | 多送一筆輸出 | 必須出現一個 EXTRA error |
| Scoreboard 反向 self-test | 少送一筆輸出 | 必須出現一個 COUNT error |

反向測試中的預期 error 是驗證檢查器的手段。它們只有在指定 error 被抓到、沒有 fatal、沒有 timeout 且模擬器正常退出時，才算 self-test 通過。

其他驗證：

- 一般 SV 的 `tb.sv` 重新編譯與執行成功，三筆資料正確，assertion 通過。
- `make run` 與 `make reset RUN_ARGS=+AXIS_TRACE` 正常完成。
- 用真實 UVM mismatch 呼叫 `make run`，確認 make 回傳非零退出碼。
- 執行器確認能拒絕：退出碼 0 但 UVM_ERROR 非零、缺少摘要、先前非零摘要被後來的零摘要遮掩、wall timeout。
- 反向測試即使已出現預期 error，也不能把後續 timeout 當作通過。
- SMT 啟動入口確認 SAT、get-value、UNSAT assumptions 與 reset 後重新求解可運作；六個 FIFO 測試也實際使用了 constraint randomization。
- 六個 FIFO 案例的 stall 與 packet length coverpoint 都是 100%。

## Reset 波形確認

`make reset RUN_ARGS=+AXIS_TRACE` 會更新 `uvm_axis.vcd`：

- Reset 在 130 ns 拉低，160 ns 解除。
- Reset 前確實有未握手 beat；上一筆輸入握手是在 105 ns。
- Driver 在 reset 拉低時將 valid 清為 0；reset 後第一筆輸入與被中斷的 payload 相同。
- 全程 45 次輸入握手、41 次輸出握手；輸入 9 個 stall 上升緣、輸出 58 個。
- Stall 期間 valid 與 payload 保持穩定；reset 期間的 clock 上升緣 valid 為 0。

## 檢查範圍與限制

目前是 32-bit、keep 固定全 1、FIFO 深度 4 的教學環境。已檢查其 agent/env 連線、monitor 採樣、scoreboard 佇列、同拍輸入輸出、排空等待與既定 reset 情境。

不同 seed 變動 payload；packet 長度與 backpressure 排程仍是固定輪替。100% coverage 只代表目前定義的 bins 全部命中。其他 FIFO 深度、部分 keep、任意時刻或多次 reset、4-state X/Z 偵測，尚未包含在這次驗收範圍。

Runtime 沿用 UVM_NO_DPI 的兩個 warning；編譯仍有 UVM library／field macro 展開的 timescale、width warnings，沒有編譯 error。Z3 fallback 是供目前 Verilator SMT 命令使用的入口，保留 shared library 的限制；若要擴展複雜 constraints，優先使用完整的系統 z3 執行檔。

重跑：

```bash
make regression
make reset RUN_ARGS=+AXIS_TRACE
```

測試 log 與 coverage database 在 `logs/`；架構說明見 [STEP9_ARCHITECTURE.md](STEP9_ARCHITECTURE.md)。
