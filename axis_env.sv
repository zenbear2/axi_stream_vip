class axis_env extends uvm_env;
  `uvm_component_utils(axis_env)

  axis_source_agent source;
  axis_monitor output_mon;
  axis_scoreboard sb;
  axis_coverage cov;

  function new(string name = "axis_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    source = axis_source_agent::type_id::create("source", this);
    output_mon = axis_monitor::type_id::create("output_mon", this);
    sb = axis_scoreboard::type_id::create("sb", this);
    cov = axis_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    source.mon.ap.connect(sb.input_export);
    output_mon.ap.connect(sb.output_export);
    output_mon.ap.connect(cov.analysis_export);
  endfunction
endclass
