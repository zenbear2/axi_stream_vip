class axis_basic_seq extends uvm_sequence #(axis_item);
  `uvm_object_utils(axis_basic_seq)

  function new(string name = "axis_basic_seq");
    super.new(name);
  endfunction

  task body();
    axis_item item;

    for (int i = 0; i < 3; i++) begin
      item = axis_item::type_id::create(
        $sformatf("item_%0d", i)
      );

      start_item(item);

      case (i)
        0: item.data = 32'h1111_1111;
        1: item.data = 32'h2222_2222;
        2: item.data = 32'h3333_3333;
      endcase

      item.keep = 4'b1111;
      item.last = (i == 2);

      finish_item(item);
    end
  endtask
endclass
