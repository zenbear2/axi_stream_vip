class axis_monitor extends uvm_monitor;
  `uvm_component_utils(axis_monitor)

  virtual axis_if vif;
  uvm_analysis_port #(axis_item) ap;

  function new(string name = "axis_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "axis_monitor requires vif")
  endfunction

  task run_phase(uvm_phase phase);
    axis_item item;
    int unsigned stalled = 0;

    forever begin
      @(posedge vif.aclk or negedge vif.aresetn);
      if (!vif.aresetn) begin
        stalled = 0;
        continue;
      end
      if (vif.tvalid && !vif.tready)
        stalled++;
      // 只觀察 reset 解除後真正完成的傳輸，不驅動介面。
      if (vif.aresetn && vif.tvalid && vif.tready) begin
        // 每次握手建立新物件，避免下游保存的 item 被後續修改。
        item = axis_item::type_id::create("item");
        item.data = vif.tdata;
        item.keep = vif.tkeep;
        item.last = vif.tlast;
        item.stall_cycles = stalled;
        stalled = 0;

        `uvm_info(
          "MON",
          $sformatf("Observed transfer: data=%08h keep=%b last=%b",
                    item.data, item.keep, item.last),
          UVM_LOW
        )

        // 每個 monitor 可連接 scoreboard、coverage 等多個 subscriber。
        ap.write(item);
      end
    end
  endtask
endclass
