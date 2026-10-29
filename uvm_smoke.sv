package axis_test_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axis_item.sv"
  `include "axis_basic_seq.sv"
  `include "axis_random_seq.sv"
  `include "axis_driver.sv"
  `include "axis_monitor.sv"
  `include "axis_source_agent.sv"
  `include "axis_scoreboard.sv"
  `include "axis_coverage.sv"
  `include "axis_env.sv"

  class axis_smoke_test extends uvm_test;
    `uvm_component_utils(axis_smoke_test)

    axis_env env;
    virtual axis_if input_vif;

    function new(string name = "axis_smoke_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = axis_env::type_id::create("env", this);
      if (!uvm_config_db#(virtual axis_if)::get(this, "", "input_vif", input_vif))
        `uvm_fatal("NOVIF", "test requires input_vif")
    endfunction

    task run_phase(uvm_phase phase);
      axis_random_seq seq;
      phase.raise_objection(this);
      seq = axis_random_seq::type_id::create("seq");
      seq.start(env.source.seqr);
      if ($test$plusargs("AXIS_RESET") && env.source.drv.reset_retries != 1)
        `uvm_error("RETRY", "Reset test must interrupt and retry one unaccepted beat")
      // 輸入送完不代表 FIFO 輸出完成。
      env.sb.wait_for_drain();
      // 多觀察幾拍，讓 scoreboard 也能抓到排空後的額外輸出。
      repeat (3) @(negedge input_vif.aclk);
      phase.drop_objection(this);
    endtask
  endclass

  // 只在 +UVM_TESTNAME=axis_scoreboard_self_test 時執行。
  `include "tests/axis_scoreboard_self_test.sv"
endpackage

module uvm_top;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import axis_test_pkg::*;

  bit aclk = 0;
  bit aresetn = 0;
  bit reset_mode;
  always #5ns aclk = ~aclk;

  axis_if #(.DATA_WIDTH(32)) s_axis (.aclk(aclk), .aresetn(aresetn));
  axis_if #(.DATA_WIDTH(32)) m_axis (.aclk(aclk), .aresetn(aresetn));
  axis_fifo #(.DEPTH(4)) dut (.s_axis(s_axis), .m_axis(m_axis));

  initial begin
    reset_mode = $test$plusargs("AXIS_RESET");
    if ($test$plusargs("AXIS_TRACE")) begin
      $dumpfile("uvm_axis.vcd");
      $dumpvars(0, uvm_top);
    end

    repeat (3) @(negedge aclk);
    aresetn = 1;

    if (reset_mode) begin
      // 刻意讓 FIFO 填滿且 source 仍有一筆等待握手，再中途 reset。
      // 在上升緣確認尚未握手，避免被握手後、NBA 更新的 ready 誤觸發。
      do begin
        @(posedge aclk);
      end while (!(s_axis.tvalid && !s_axis.tready && m_axis.tvalid && !m_axis.tready));
      @(negedge aclk);
      aresetn = 0;
      repeat (3) @(negedge aclk);
      aresetn = 1;
    end
  end

  initial begin
    int unsigned slot;
    int unsigned stalls;
    slot = 0;
    m_axis.tready = 0;
    wait (aresetn == 1'b1);
    // reset 測試先不開放 sink，確保真的清除 FIFO 內的資料。
    if ($test$plusargs("AXIS_RESET")) begin
      wait (aresetn == 1'b0);
      wait (aresetn == 1'b1);
    end
    @(negedge aclk);
    forever begin
      case (slot % 4)
        0: stalls = 0;
        1: stalls = 1;
        2: stalls = 3;
        3: stalls = 6;
      endcase
      m_axis.tready = 0;
      repeat (stalls) @(negedge aclk);
      m_axis.tready = 1;
      repeat (2) @(negedge aclk);
      slot++;
    end
  end

  initial begin
    // 對每個元件精確指定介面，避免把輸入／輸出接反。
    uvm_config_db#(virtual axis_if)::set(null, "uvm_test_top", "input_vif", s_axis);
    uvm_config_db#(virtual axis_if)::set(null, "uvm_test_top.env.source.*", "vif", s_axis);
    uvm_config_db#(virtual axis_if)::set(null, "uvm_test_top.env.sb", "vif", s_axis);
    uvm_config_db#(virtual axis_if)::set(null, "uvm_test_top.env.output_mon", "vif", m_axis);
    uvm_config_db#(virtual axis_if)::set(null, "uvm_test_top.env.cov", "vif", m_axis);
    run_test("axis_smoke_test");
  end

  initial begin
    #100us;
    $fatal(1, "Simulation timeout");
  end
endmodule
