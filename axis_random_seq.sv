class axis_random_seq extends uvm_sequence #(axis_item);
  `uvm_object_utils(axis_random_seq)

  int unsigned num_packets = 12;

  function new(string name = "axis_random_seq");
    super.new(name);
  endfunction

  task body();
    axis_item item;
    int unsigned packet_length;

    for (int p = 0; p < num_packets; p++) begin
      // 長度輪替，讓每次測試都涵蓋短、中、長 packet；payload 隨機。
      case (p % 4)
        0: packet_length = 8;
        1: packet_length = 1;
        2: packet_length = 2;
        3: packet_length = 4;
      endcase
      for (int b = 0; b < packet_length; b++) begin
        item = axis_item::type_id::create($sformatf("packet_%0d_beat_%0d", p, b));
        start_item(item);
        if (!item.randomize())
          `uvm_fatal("RAND", "axis_item randomize failed")
        item.last = (b == packet_length - 1);
        finish_item(item);
      end
    end
  endtask
endclass
