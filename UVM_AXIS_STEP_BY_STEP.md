# 用 AXI Stream 一步一步學 UVM

這份練習以你現有的 Verilog／SystemVerilog 基礎為出發點。每完成一個步驟，先編譯、執行並確認驗收條件，再繼續下一步。先做固定資料，最後才加入隨機化。

目前程式已推進到 STEP 9。以下 STEP 1–8 保留為概念演進的練習說明；現行架構與編譯指令請看 [STEP9_ARCHITECTURE.md](STEP9_ARCHITECTURE.md)，使用 `make build`、`make run`、`make reset`、`make regression`。

第一輪目標：讓 sequence 產生三個 beat，driver 經由 `axis_if` 送出，monitor 正確觀察三次握手，checker 自動確認內容與順序。

## 0. 認識目前的起點

| 檔案 | 目前的用途 |
| --- | --- |
| `axis_if.sv` | AXIS 訊號、modport，以及 stall 時保持資料的 assertion |
| `tb.sv` | 非 UVM 範例：送三個 beat、產生 backpressure、印出握手 |
| `axis_item.sv` | 一個 beat 的 transaction，包含 `data`、`keep`、`last` |
| `uvm_smoke.sv` | package、`axis_smoke_test`、`uvm_top`；目前只建立並印出 item |

目前 UVM library 路徑為 `/home/user/tools/uvm-2020.3.1`，系統 Verilator 為 5.052。

這裡的一個 item 代表一個 **beat**，並非整個 packet。連續三個 beat 的 `last` 依序為 0、0、1，才構成我們這次練習的 packet。

先記住這個條件：

```systemverilog
// 在 clock 上升緣判斷
aresetn && tvalid && tready
```

條件成立才算傳輸。`tvalid=1` 但 `tready=0` 時，source 必須保持 valid 與 payload，不能跳到下一筆。

## 1. 重跑兩個現有範例

在專案根目錄使用系統安裝的 Verilator；清除先前可能設定的專案工具路徑影響：

```bash
unset VERILATOR_ROOT
export PATH="/usr/local/bin:$PATH"
hash -r
verilator --version
export UVM_HOME=/home/user/tools/uvm-2020.3.1
```

先跑一般 SV 範例：

```bash
verilator --binary --timing --assert --trace --top-module tb \
  --Mdir obj_dir axis_if.sv tb.sv
./obj_dir/Vtb
```

驗收：依序看到 `11111111`、`22222222`、`33333333`，最後一筆 `last=1`，沒有 assertion failure。

再跑 UVM 範例。後續步驟都使用這組指令重新編譯：

```bash
verilator --binary --timing --assert --trace -j 2 -Wno-fatal \
  +define+UVM_NO_DPI \
  +incdir+"$UVM_HOME/src" +incdir+. \
  --top-module uvm_top --Mdir obj_uvm \
  "$UVM_HOME/src/uvm_pkg.sv" axis_if.sv uvm_smoke.sv
./obj_uvm/Vuvm_top
```

`axis_item.sv` 已被 package include，不要再把它獨立列為編譯來源。後面新增的 class 也採同樣做法。`tb.sv` 有自己的時脈與傳輸流程，這組 UVM 指令不編譯它。

`--assert` 啟用 assertion；`--trace` 支援 `$dumpvars` 波形輸出；`UVM_NO_DPI` 沿用你現有 smoke test 的設定，會有停用 DPI 相關的 warning。`-Wno-fatal` 讓 warning 不直接中止編譯，仍需閱讀 warning。

- [ ] 出現 `Running test axis_smoke_test`。
- [ ] item 印出 `data=1234abcd`、`keep=1111`、`last=1`。
- [ ] `UVM_ERROR` 與 `UVM_FATAL` 都是 0。

思考：為什麼目前測試在時間 0 就結束？因為它只有建立物件，沒有等待時脈或發送介面訊號。

## 2. 把 clock、reset、interface 放進 UVM top

**修改位置：`uvm_smoke.sv` 的 `module uvm_top`。**

參考 `tb.sv`，加入以下內容：

1. `aclk` 初值 0，每 5 ns 反相。
2. `aresetn` 初值 0，第三個下降緣解除 reset。
3. 實例化 `axis_if #(.DATA_WIDTH(32)) axis (...)`。
4. 先讓 sink 的 `axis.tready` 固定為 1。
5. 加入 `$dumpfile("uvm_axis.vcd")` 與 `$dumpvars(0, uvm_top)`。
6. 加入獨立 timeout：`#1000; $fatal(1, "Simulation timeout");`。

在**同一個 initial block** 裡，先傳遞 interface handle，再呼叫 `run_test`：

```systemverilog
initial begin
  uvm_config_db#(virtual axis_if)::set(
    null, "uvm_test_top.*", "vif", axis
  );
  run_test("axis_smoke_test");
end
```

本練習的 virtual interface 使用預設 32-bit `axis_if`。set、get 與成員宣告都先保持相同型別，不要混用帶 modport 與不帶 modport 的型別。

注意：現在 smoke test 仍會在時間 0 結束。暫時在 test 的 objection 範圍內加 `#100ns`，確認波形中的 clock/reset，下一步開始送資料時再移除。

- [ ] 波形有 10 ns clock，reset 在 30 ns 解除。
- [ ] 知道 module 裡的 interface instance 與 class 裡的 virtual interface handle 有何不同。

## 3. 寫一個只負責產生資料的 sequence

**新增：`axis_basic_seq.sv`。**

類別骨架：

```systemverilog
class axis_basic_seq extends uvm_sequence #(axis_item);
  `uvm_object_utils(axis_basic_seq)

  function new(string name = "axis_basic_seq");
    super.new(name);
  endfunction

  task body();
    // TODO：依序建立並送出三個 item
  endtask
endclass
```

在 `body()` 中，對每個 beat 執行：

```systemverilog
item = axis_item::type_id::create("item");
start_item(item);
// TODO：設定 data、keep、last
finish_item(item);
```

請自行宣告 `axis_item item`。三筆資料沿用 `tb.sv`：

| 次序 | data | keep | last |
| --- | --- | --- | --- |
| 0 | `32'h1111_1111` | `4'b1111` | 0 |
| 1 | `32'h2222_2222` | `4'b1111` | 0 |
| 2 | `32'h3333_3333` | `4'b1111` | 1 |

在 package 的 `axis_item.sv` include 後面，加入 `axis_basic_seq.sv` 的 include。

- [ ] 能編譯。此時 sequence 還沒有被啟動，因此不會送出資料。
- [ ] sequence 不直接存取 `tvalid`、`tready` 或時脈。
- [ ] 能解釋：sequence 決定送什麼，driver 決定怎麼送。

## 4. 建立 driver，將 item 轉成 AXIS 時序

**新增：`axis_driver.sv`。**

建立 `axis_driver extends uvm_driver #(axis_item)`，使用 `uvm_component_utils` 註冊。constructor 採用與 test 相同的 `name`、`parent` 形式，並呼叫 `super.new(name, parent)`。

宣告：

```systemverilog
virtual axis_if vif;
```

在 `build_phase` 中呼叫 `super.build_phase(phase)`，並取得 interface：

```systemverilog
if (!uvm_config_db#(virtual axis_if)::get(this, "", "vif", vif))
  `uvm_fatal("NOVIF", "axis_driver requires vif")
```

在 `run_phase` 中，先將 source 的 `tvalid`、`tdata`、`tkeep`、`tlast` 初始化為 0。接著使用以下流程：

```text
等待 reset 已解除
forever:
    get_next_item(req)
    將 req 送到介面，等待握手成功
    item_done()
```

取得資料與回報完成的 API：

```systemverilog
seq_item_port.get_next_item(req);
// TODO：把 tb.sv 的 send_beat 邏輯搬過來，訊號改成 vif.xxx
seq_item_port.item_done();
```

`req` 是 `uvm_driver #(axis_item)` 提供的成員。可新增 `task drive_beat(axis_item item)`，由 `run_phase` 呼叫。

實作時遵守：

- 使用 `wait (vif.aresetn == 1'b1)` 等待 reset，避免 reset 已解除後才等上升緣而卡住。
- 在下降緣設定 valid 與 payload，在上升緣確認 ready。
- 至少等一個上升緣；等待 ready 期間不能更換 payload。
- 握手後，在下一個下降緣拉低 valid，再呼叫 `item_done()`。
- driver 只驅動 source 訊號；`tready` 由 top 的 sink 流程控制。

這版允許 beat 之間有空拍，先求正確。練習只在開頭 reset；傳輸途中 reset 的取消／重送策略留到後面。

在 package 裡 include `axis_driver.sv`，放在 test 定義之前。

- [ ] driver 能編譯；下一步建立實例後才能觀察傳輸。
- [ ] 知道 `item_done()` 表示 driver 已完成該筆工作，不能在真正握手前呼叫。

## 5. 在 test 直接連接 sequencer 與 driver

**修改：`axis_smoke_test`。先直接在 test 組裝，下一輪再抽成 agent/env。**

新增成員：

```systemverilog
uvm_sequencer #(axis_item) seqr;
axis_driver drv;
```

在 `build_phase` 建立：

```systemverilog
seqr = uvm_sequencer#(axis_item)::type_id::create("seqr", this);
drv = axis_driver::type_id::create("drv", this);
```

新增 `connect_phase`：

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  drv.seq_item_port.connect(seqr.seq_item_export);
endfunction
```

將原本只印 item 的 `run_phase` 改成以下流程，移除步驟 2 的暫時延遲：

```systemverilog
task run_phase(uvm_phase phase);
  axis_basic_seq seq;
  phase.raise_objection(this);
  seq = axis_basic_seq::type_id::create("seq");
  seq.start(seqr);
  phase.drop_objection(this);
endtask
```

在 top 暫時加入與 `tb.sv` 相同的握手 `$display`，先觀察行為。source 訊號全部交由 driver 控制，別再複製 top 的 source initial block。

- [ ] 重新編譯並執行，出現三筆正確傳輸。
- [ ] 最後一筆 `last=1`。
- [ ] 波形顯示傳輸發生在 reset 解除之後。
- [ ] `UVM_ERROR`、`UVM_FATAL` 為 0，介面 assertion 通過。

理解這條路徑：

```text
axis_basic_seq → seqr → drv → axis_if
     item          item        訊號
```

`seq.start(seqr)` 要等 sequence 的 `body()` 結束才返回；`finish_item()` 會等待 driver 回報完成。

## 6. 加入 monitor，只記錄成功握手

**新增：`axis_monitor.sv`，並在 package 的 test 定義前 include。**

建立 `axis_monitor extends uvm_monitor`，註冊 component factory，加入 constructor、`virtual axis_if vif`，並在 `build_phase` 用與 driver 相同的方法 get `vif`。

宣告 analysis port，並在 constructor 建立：

```systemverilog
uvm_analysis_port #(axis_item) ap;
// constructor 中：
ap = new("ap", this);
```

在 `run_phase` 每個上升緣檢查 reset 與握手條件。只有條件成立時才：

1. 用 factory 建立一個新的 `axis_item`。
2. 將介面的 `tdata`、`tkeep`、`tlast` 複製到 item。
3. 印出 item。
4. 呼叫 `ap.write(item)`。

每次觀察都建立新物件，避免接收端保存的 handle 指向同一個反覆被修改的物件。

在 test 宣告 `axis_monitor mon`，於 `build_phase` 建立 `mon`。這一步 analysis port 暫時沒有 subscriber 也可以。

- [ ] 移除 top 暫時的握手 display 後，monitor 仍印出三筆資料。
- [ ] monitor 不驅動任何介面訊號，也不向 driver 詢問傳了什麼。
- [ ] monitor 的 item 來自介面觀察，而非直接重用 sequence 的 item。

## 7. 加入自動 checker，避免只靠肉眼看 log

**新增：`axis_checker.sv`，在 test 定義前 include。**

第一版可繼承 `uvm_subscriber #(axis_item)`，使用它內建的 `analysis_export`。這裡還沒有 DUT，checker 檢查的是 driver 實際送出的 stimulus。

實作 `function void write(axis_item t)`：

1. 用計數器 `count` 判斷目前應收到哪一筆。
2. 依步驟 3 的表格檢查 `data`、`keep`、`last`。
3. 不符合時使用 `uvm_error`，列出次序、預期與實際值。
4. 收到超過三筆也要報錯。
5. 更新 `count`。

在 `check_phase` 檢查總數恰好為 3，避免少收資料卻通過。

在 test 宣告、建立 `axis_checker chk`，並在 `connect_phase` 加入（`checker` 是 SystemVerilog 保留字，不可當變數名稱）：

```systemverilog
mon.ap.connect(chk.analysis_export);
```

目前 driver 在最後一次握手後的下降緣才 `item_done()`，monitor 已有機會在該握手上升緣同步呼叫 `write()`；不要把 driver 改成提早回報完成。

- [ ] 正常資料下，checker 收到三筆，零 error。
- [ ] 暫時把 sequence 第二筆資料改錯，checker 必須報錯；驗證後改回。
- [ ] 暫時少送一筆，`check_phase` 必須報錯；驗證後改回。

## 8. 恢復 backpressure

**修改：`uvm_top` 的 sink 流程。**

把固定 `tready=1` 改成 `tb.sv` 的做法：

```text
初始化 ready=0
等待 reset 解除
forever:
    等待三個下降緣，ready=1
    等待兩個下降緣，ready=0
```

只保留一個控制 `tready` 的流程。

- [ ] checker 仍只收到三筆正確資料。
- [ ] 波形中至少發生一次 `tvalid=1 && tready=0`。
- [ ] stall 期間 valid 與 payload 保持不變，介面 assertion 通過。
- [ ] 不會把同一筆 stall 中的資料重複計入 monitor。

## 9. 完成第一輪後再整理結構

已實作版本的元件關係、reset 規則與驗收方式，請看 [STEP9_ARCHITECTURE.md](STEP9_ARCHITECTURE.md)。

建議依照下面順序繼續，一次只做一項：

1. **Agent**：新增 `axis_source_agent`，把 `seqr`、`drv`、`mon` 與內部連線搬進去。
2. **Environment**：新增 `axis_env`，包含 source agent 與 checker，負責 analysis 連線。
3. **隨機資料**：在 sequence 使用 `randomize()`，先約束 `keep == 4'b1111`；每次檢查 randomize 的回傳值。
4. **預期值佇列**：隨機化後改用 expected queue 比對，不能再依賴三筆固定常數。
5. **加入 AXIS FIFO DUT**：建立輸入與輸出介面，分別監看，scoreboard 將輸入握手的資料入列，於輸出握手時依序比對。
6. **等待 DUT 排空**：有 DUT 後，sequence 結束不代表輸出已完成；等待預期輸出全部收到，並設 timeout，最後才 drop objection。
7. **Coverage 與 reset 測試**：確認不同 stall 長度、packet 長度都被測到，再定義傳輸途中 reset 的預期行為。

## 編譯或執行卡住時

| 現象 | 先檢查 |
| --- | --- |
| 找不到 class | package include 順序；不要把 class 檔重複獨立編譯 |
| `NOVIF` | set 是否在 run_test 前；instance path 與 virtual interface 型別是否一致 |
| sequence 卡在 `finish_item` | sequencer/driver 是否 connect；driver 是否呼叫 item_done；ready 是否會變成 1 |
| 時間 0 結束 | test 是否 raise objection；是否真的呼叫 seq.start |
| timeout | reset 是否解除、driver 是否等待不存在的 reset edge、sink 是否開放 ready |
| 一筆資料收到多次 | driver 是否在握手後適時拉低 valid；monitor 是否只在握手時記錄 |
| stall assertion 失敗 | driver 是否在 ready=0 時換資料或拉低 valid |

## 每次練習的紀錄

完成一步後，自己寫下三句話：

1. 這次新增的元件負責什麼？
2. 它透過什麼方式與其他元件溝通？
3. 我用什麼結果證明它有正確運作？

先完成步驟 1，再逐步往下做。遇到問題時保留完整錯誤訊息與目前做到的步驟，會比較容易定位原因。
