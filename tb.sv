module tb;

  timeunit 1ns;
  timeprecision 1ps;

  bit aclk = 0;
  bit aresetn = 0;

  always #5 aclk = ~aclk;

  axis_if #(
    .DATA_WIDTH(32)
  ) axis (
    .aclk    (aclk),
    .aresetn (aresetn)
  );

  // Source：送出一個 beat，等到握手成功才返回
  task automatic send_beat(
    input logic [31:0] data,
    input logic [3:0]  keep,
    input logic        last
  );
    @(negedge aclk);
    axis.tvalid = 1;
    axis.tdata  = data;
    axis.tkeep  = keep;
    axis.tlast  = last;

    // 至少等待一個上升緣，再檢查是否握手
    do begin
      @(posedge aclk);
    end while (!axis.tready);

    @(negedge aclk);
    axis.tvalid = 0;
    axis.tlast  = 0;
  endtask

  // Clock/reset 之外的模擬設定
  initial begin
    $dumpfile("axis.vcd");
    $dumpvars(0, tb);

    repeat (3) @(negedge aclk);
    aresetn = 1;
  end

  // Source 流程：送一個由三個 beat 組成的 packet
  initial begin
    axis.tvalid = 0;
    axis.tdata  = '0;
    axis.tkeep  = '0;
    axis.tlast  = 0;

    @(posedge aresetn);

    send_beat(32'h1111_1111, 4'b1111, 0);
    send_beat(32'h2222_2222, 4'b1111, 0);
    send_beat(32'h3333_3333, 4'b1111, 1);

    repeat (2) @(negedge aclk);
    $finish;
  end

  // Sink 流程：獨立控制 backpressure
  initial begin
    axis.tready = 0;

    @(posedge aresetn);

    forever begin
      // 暫停接收三個週期
      repeat (3) @(negedge aclk);
      axis.tready = 1;

      // 開放接收兩個週期
      repeat (2) @(negedge aclk);
      axis.tready = 0;
    end
  end

  // Monitor：只記錄實際成功的傳輸
  always @(posedge aclk) begin
    if (aresetn && axis.tvalid && axis.tready) begin
      $display(
        "[%0t] Transfer: data=%08h keep=%b last=%b",
        $time, axis.tdata, axis.tkeep, axis.tlast
      );
    end
  end

  initial begin
    #1000;
    $fatal(1, "Simulation timeout");
  end

endmodule
