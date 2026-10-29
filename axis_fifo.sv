// 教學用同步 AXIS FIFO：儲存每個 beat 的 data/keep/last。
module axis_fifo #(
  parameter int DEPTH = 4
)(
  axis_if.sink s_axis,
  axis_if.source m_axis
);
  timeunit 1ns;
  timeprecision 1ps;

  localparam int DATA_WIDTH = $bits(s_axis.tdata);
  localparam int KEEP_WIDTH = $bits(s_axis.tkeep);
  localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
  localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

  logic [DATA_WIDTH-1:0] data_mem [DEPTH];
  logic [KEEP_WIDTH-1:0] keep_mem [DEPTH];
  logic last_mem [DEPTH];
  logic [PTR_WIDTH-1:0] rd_ptr, wr_ptr;
  logic [COUNT_WIDTH-1:0] count;
  logic push, pop;

  initial begin
    if (DEPTH < 1)
      $fatal(1, "AXIS FIFO DEPTH must be positive");
  end

  // 滿時若同拍有輸出，也允許輸入，以維持吞吐量。
  assign m_axis.tvalid = s_axis.aresetn && (count != 0);
  assign s_axis.tready = s_axis.aresetn &&
                         ((count < COUNT_WIDTH'(DEPTH)) || m_axis.tready);
  assign m_axis.tdata = data_mem[rd_ptr];
  assign m_axis.tkeep = keep_mem[rd_ptr];
  assign m_axis.tlast = last_mem[rd_ptr];
  assign push = s_axis.tvalid && s_axis.tready;
  assign pop = m_axis.tvalid && m_axis.tready;

  always_ff @(posedge s_axis.aclk or negedge s_axis.aresetn) begin
    if (!s_axis.aresetn) begin
      rd_ptr <= '0;
      wr_ptr <= '0;
      count <= '0;
    end else begin
      if (push) begin
        data_mem[wr_ptr] <= s_axis.tdata;
        keep_mem[wr_ptr] <= s_axis.tkeep;
        last_mem[wr_ptr] <= s_axis.tlast;
        wr_ptr <= (wr_ptr == PTR_WIDTH'(DEPTH - 1)) ? '0 : wr_ptr + 1'b1;
      end
      if (pop)
        rd_ptr <= (rd_ptr == PTR_WIDTH'(DEPTH - 1)) ? '0 : rd_ptr + 1'b1;
      case ({push, pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: ;
      endcase
    end
  end

  a_count_in_range: assert property (
    @(posedge s_axis.aclk) disable iff (!s_axis.aresetn)
    count <= COUNT_WIDTH'(DEPTH)
  ) else $fatal(1, "AXIS FIFO count out of range");
endmodule
