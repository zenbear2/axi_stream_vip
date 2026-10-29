`uvm_analysis_imp_decl(_input)
`uvm_analysis_imp_decl(_output)

class axis_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axis_scoreboard)

  uvm_analysis_imp_input #(axis_item, axis_scoreboard) input_export;
  uvm_analysis_imp_output #(axis_item, axis_scoreboard) output_export;
  virtual axis_if vif;
  axis_item expected[$];
  int unsigned accepted_count, matched_count, flushed_count, reset_count;

  function new(string name = "axis_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    input_export = new("input_export", this);
    output_export = new("output_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "axis_scoreboard requires input vif")
  endfunction

  function void write_input(axis_item t);
    // Monitor 每次建立新物件；scoreboard 仍複製 payload 以獨立持有預期值。
    axis_item copy;
    copy = axis_item::type_id::create("expected_item");
    copy.copy(t);
    expected.push_back(copy);
    accepted_count++;
  endfunction

  function void write_output(axis_item t);
    axis_item exp;
    if (expected.size() == 0) begin
      `uvm_error("EXTRA", "FIFO output has no matching input")
      return;
    end
    exp = expected.pop_front();
    if (t.data !== exp.data || t.keep !== exp.keep || t.last !== exp.last)
      `uvm_error("MISMATCH", $sformatf(
        "Expected data=%08h keep=%b last=%b; got data=%08h keep=%b last=%b",
        exp.data, exp.keep, exp.last, t.data, t.keep, t.last))
    matched_count++;
  endfunction

  task run_phase(uvm_phase phase);
    wait (vif.aresetn == 1'b1);
    forever begin
      @(negedge vif.aresetn);
      reset_count++;
      flushed_count += expected.size();
      `uvm_info("FLUSH", $sformatf("Reset discards %0d pending beats", expected.size()), UVM_LOW)
      expected.delete();
    end
  endtask

  task wait_for_drain();
    // Sequence 結束後，繼續保持 objection 直到 FIFO 排空。
    for (int cycles = 0; cycles < 1000; cycles++) begin
      @(negedge vif.aclk);
      if (expected.size() == 0)
        return;
    end
    `uvm_fatal("DRAIN_TIMEOUT", $sformatf("FIFO did not drain: %0d pending", expected.size()))
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expected.size() != 0 || accepted_count == 0 || matched_count == 0 ||
        accepted_count != matched_count + flushed_count)
      `uvm_error("COUNT", $sformatf("accepted=%0d compared=%0d flushed=%0d pending=%0d",
                  accepted_count, matched_count, flushed_count, expected.size()))
    if ($test$plusargs("AXIS_RESET") && (reset_count != 1 || flushed_count == 0))
      `uvm_error("RESET", "Reset scenario must flush a nonempty FIFO exactly once")
    `uvm_info("SCOREBOARD", $sformatf("accepted=%0d compared=%0d flushed=%0d pending=%0d resets=%0d",
                accepted_count, matched_count, flushed_count, expected.size(), reset_count), UVM_LOW)
  endfunction
endclass
