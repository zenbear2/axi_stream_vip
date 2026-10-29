class axis_checker extends uvm_subscriber #(axis_item);
  `uvm_component_utils(axis_checker)

  int unsigned count = 0;

  function new(string name = "axis_checker", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // analysis_export 收到 monitor 的 item 時，會同步呼叫 write。
  function void write(axis_item t);
    bit [31:0] expected_data;
    bit expected_last;

    case (count)
      0: expected_data = 32'h1111_1111;
      1: expected_data = 32'h2222_2222;
      2: expected_data = 32'h3333_3333;
      default: begin
        `uvm_error("EXTRA", $sformatf("Unexpected beat %0d: data=%08h",
                                     count, t.data))
        count++;
        return;
      end
    endcase
    expected_last = (count == 2);

    if (t.data !== expected_data || t.keep !== 4'b1111 ||
        t.last !== expected_last) begin
      `uvm_error(
        "MISMATCH",
        $sformatf("Beat %0d: expected data=%08h keep=1111 last=%b; got data=%08h keep=%b last=%b",
                  count, expected_data, expected_last, t.data, t.keep, t.last)
      )
    end
    count++;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (count != 3)
      `uvm_error("COUNT", $sformatf("Expected 3 beats, received %0d", count))
    else
      `uvm_info("COUNT", "Received all 3 expected beats; see report summary for errors", UVM_LOW)
  endfunction
endclass
