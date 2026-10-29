class axis_item extends uvm_sequence_item;

  rand bit [31:0] data;
  rand bit [3:0]  keep;
  rand bit        last;

  constraint full_keep_c { keep == 4'b1111; }

  // Monitor 記錄的等待週期，不屬於 payload，也不參與隨機化。
  int unsigned stall_cycles;

  // 註冊 factory 與欄位
  `uvm_object_utils_begin(axis_item)
    `uvm_field_int(data, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(keep, UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(last, UVM_DEFAULT | UVM_BIN)
  `uvm_object_utils_end

  function new(string name = "axis_item");
    super.new(name);
  endfunction

endclass
