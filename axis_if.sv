interface axis_if #(
  parameter int DATA_WIDTH = 32
)(
  input logic aclk,
  input logic aresetn
);

  localparam int KEEP_WIDTH = DATA_WIDTH / 8;

  logic                  tvalid;
  logic                  tready;
  logic [DATA_WIDTH-1:0] tdata;
  logic [KEEP_WIDTH-1:0] tkeep;
  logic                  tlast;

  // 傳送端看到的訊號方向
  modport source (
    input  aclk, aresetn,
    input  tready,
    output tvalid, tdata, tkeep, tlast
  );

  // 接收端看到的訊號方向
  modport sink (
    input  aclk, aresetn,
    input  tvalid, tdata, tkeep, tlast,
    output tready
  );

  // 觀察端只能讀取訊號
  modport monitor (
    input aclk, aresetn,
    input tvalid, tready, tdata, tkeep, tlast
  );

  // 上一拍未完成握手，這一拍必須保持 VALID 與 payload
  property p_hold_when_stalled;
    @(posedge aclk)
    disable iff (!aresetn)
      (tvalid && !tready)
      |=> (tvalid && $stable({tdata, tkeep, tlast}));
  endproperty

  a_hold_when_stalled:
    assert property (p_hold_when_stalled)
    else $fatal(1, "AXIS violation: source changed while stalled");

  // reset 期間的 clock 上升緣，source 不得宣告有效傳輸。
  a_valid_low_in_reset:
    assert property (@(posedge aclk) !aresetn |-> !tvalid)
    else $fatal(1, "AXIS violation: tvalid must be low during reset");
endinterface
