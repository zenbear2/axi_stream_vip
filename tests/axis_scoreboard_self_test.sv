// 驗證 scoreboard 能抓到資料錯誤、額外輸出、遺漏輸出。
// 與一般 FIFO 測試分開執行，不在預設 env 中增加元件。
class axis_scoreboard_self_test extends uvm_test;
  `uvm_component_utils(axis_scoreboard_self_test)

  axis_scoreboard sb;

  function new(string name = "axis_scoreboard_self_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual axis_if vif;
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axis_if)::get(this, "", "input_vif", vif))
      `uvm_fatal("NOVIF", "Scoreboard self-test requires input_vif")
    uvm_config_db#(virtual axis_if)::set(this, "sb", "vif", vif);
    sb = axis_scoreboard::type_id::create("sb", this);
  endfunction

  task run_phase(uvm_phase phase);
    axis_item item;
    string fault;
    int unsigned outputs;
    phase.raise_objection(this);
    fault = "none";
    void'($value$plusargs("SCOREBOARD_FAULT=%s", fault));
    if (!(fault inside {"none", "mismatch", "extra", "missing"}))
      `uvm_fatal("SELFTEST", "Unknown SCOREBOARD_FAULT")

    for (int i = 0; i < 3; i++) begin
      item = axis_item::type_id::create("input_item");
      item.data = 32'(i + 1);
      item.keep = 4'hf;
      item.last = (i == 2);
      sb.write_input(item);
      // 修改原始物件，確認 scoreboard 有獨立複製 expected item。
      item.data = '1;
    end

    outputs = (fault == "missing") ? 2 : 3;
    for (int i = 0; i < outputs; i++) begin
      item = axis_item::type_id::create("output_item");
      item.data = 32'(i + 1);
      item.keep = 4'hf;
      item.last = (i == 2);
      if (fault == "mismatch" && i == 1)
        item.data ^= 32'h1;
      sb.write_output(item);
    end
    if (fault == "extra")
      sb.write_output(item);

    phase.drop_objection(this);
  endtask
endclass
