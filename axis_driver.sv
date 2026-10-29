class axis_driver extends uvm_driver #(axis_item);
  `uvm_component_utils(axis_driver)

  virtual axis_if vif;
  int unsigned reset_retries;

  function new(string name = "axis_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "axis_driver requires vif")
  endfunction

  task run_phase(uvm_phase phase);
    vif.tvalid = 0;
    vif.tdata  = '0;
    vif.tkeep  = '0;
    vif.tlast  = 0;

    wait (vif.aresetn == 1'b1);

    forever begin
      seq_item_port.get_next_item(req);
      drive_beat(req);
      // 真正完成握手後，才讓 sequence 繼續下一筆。
      seq_item_port.item_done();
    end
  endtask

  task drive_beat(axis_item item);
    forever begin
      wait (vif.aresetn == 1'b1);
      // 在下降緣驅動，讓訊號在下一個上升緣前穩定。
      @(negedge vif.aclk);
      if (!vif.aresetn)
        continue;
      vif.tvalid = 1;
      vif.tdata  = item.data;
      vif.tkeep  = item.keep;
      vif.tlast  = item.last;

      do begin
        // Reset assertion 必須能立即中斷等待，不只在 clock 上升緣察覺。
        @(posedge vif.aclk or negedge vif.aresetn);
      end while (vif.aresetn && vif.tready !== 1'b1);

      if (!vif.aresetn) begin
        // 尚未握手的 beat 不算完成；reset 後重新送同一個 item。
        vif.tvalid = 0;
        vif.tlast = 0;
        reset_retries++;
        `uvm_info("RETRY", "Reset interrupted an unaccepted beat; retry after reset", UVM_LOW)
        continue;
      end

      @(negedge vif.aclk);
      vif.tvalid = 0;
      vif.tlast  = 0;
      return;
    end
  endtask
endclass
