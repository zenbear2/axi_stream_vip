class axis_coverage extends uvm_subscriber #(axis_item);
  `uvm_component_utils(axis_coverage)

  virtual axis_if vif;
  int unsigned packet_beats;
  int unsigned packets;

  covergroup beat_cg with function sample(int unsigned stalls);
    option.per_instance = 1;
    stall_length: coverpoint stalls {
      bins none = {0};
      bins one = {1};
      bins short_stall = {[2:3]};
      bins long_stall = {[4:$]};
    }
  endgroup

  covergroup packet_cg with function sample(int unsigned length);
    option.per_instance = 1;
    packet_length: coverpoint length {
      bins single = {1};
      bins two = {2};
      bins medium_packet = {[3:4]};
      bins long_packet = {[5:8]};
      illegal_bins too_long = {[9:$]};
    }
  endgroup

  function new(string name = "axis_coverage", uvm_component parent = null);
    super.new(name, parent);
    beat_cg = new;
    packet_cg = new;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "axis_coverage requires output vif")
  endfunction

  function void write(axis_item t);
    beat_cg.sample(t.stall_cycles);
    packet_beats++;
    if (t.last) begin
      packet_cg.sample(packet_beats);
      packets++;
      packet_beats = 0;
    end
  endfunction

  task run_phase(uvm_phase phase);
    wait (vif.aresetn == 1'b1);
    forever begin
      @(negedge vif.aresetn);
      packet_beats = 0;
    end
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (packet_beats != 0)
      `uvm_error("PACKET", "Test ended with an incomplete output packet")
    if (beat_cg.get_inst_coverage() < 100.0 || packet_cg.get_inst_coverage() < 100.0)
      `uvm_error("COVERAGE", "Not all requested stall/packet length bins were exercised")
    `uvm_info("COVERAGE", $sformatf("stall=%0.1f%% packet=%0.1f%% completed_packets=%0d",
                beat_cg.get_inst_coverage(), packet_cg.get_inst_coverage(), packets), UVM_LOW)
  endfunction
endclass
