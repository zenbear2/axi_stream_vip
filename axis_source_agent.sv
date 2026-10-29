class axis_source_agent extends uvm_agent;
  `uvm_component_utils(axis_source_agent)

  uvm_sequencer #(axis_item) seqr;
  axis_driver drv;
  axis_monitor mon;

  function new(string name = "axis_source_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqr = uvm_sequencer#(axis_item)::type_id::create("seqr", this);
    drv = axis_driver::type_id::create("drv", this);
    mon = axis_monitor::type_id::create("mon", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass
