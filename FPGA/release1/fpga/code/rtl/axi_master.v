//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.07.2014 22:57:49
// Design Name: 
// Module Name: axi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axi_dump2ddr_master #(
    parameter   AXI_DW  =  64           , // data width (8,16,...,1024)
    parameter   AXI_AW  =  32           , // AXI address width
    parameter   AXI_IW  =   6           , // AXI ID width
    parameter   AXI_SW  = AXI_DW >> 3   , // AXI strobe width - 1 bit for every data byte
    parameter   BUF_AW  =  12           , // buffer address width
    parameter   BUF_CH  =   2             // number of buffered channels
)(
    output [AXI_AW-1:0] axi_araddr_o    ,
    output [       1:0] axi_arburst_o   ,
    output [       3:0] axi_arcache_o   ,
    output [AXI_IW-1:0] axi_arid_o      ,
    output [       3:0] axi_arlen_o     ,
    output [       1:0] axi_arlock_o    ,
    output [       2:0] axi_arprot_o    ,
    output [       3:0] axi_arqos_o     ,
    input               axi_arready_i   ,
    output [       2:0] axi_arsize_o    ,
    output              axi_arvalid_o   ,
    output [AXI_AW-1:0] axi_awaddr_o    ,
    output [       1:0] axi_awburst_o   ,
    output [       3:0] axi_awcache_o   ,
    output [AXI_IW-1:0] axi_awid_o      ,
    output [       3:0] axi_awlen_o     ,
    output [       1:0] axi_awlock_o    ,
    output [       2:0] axi_awprot_o    ,
    output [       3:0] axi_awqos_o     ,
    input               axi_awready_i   ,
    output [       2:0] axi_awsize_o    ,
    output              axi_awvalid_o   ,
    input  [AXI_IW-1:0] axi_bid_i       ,
    output              axi_bready_o    ,
    input  [       1:0] axi_bresp_i     ,
    input               axi_bvalid_i    ,
    input  [AXI_DW-1:0] axi_rdata_i     ,
    input  [AXI_IW-1:0] axi_rid_i       ,
    input               axi_rlast_i     ,
    output              axi_rready_o    ,
    input  [       1:0] axi_rresp_i     ,
    input               axi_rvalid_i    ,
    output [AXI_DW-1:0] axi_wdata_o     ,
    output [AXI_IW-1:0] axi_wid_o       ,
    output              axi_wlast_o     ,
    input               axi_wready_i    ,
    output [AXI_SW-1:0] axi_wstrb_o     ,
    output              axi_wvalid_o    ,

    input                   buf_clk_i   ,
    input                   buf_rstn_i  ,
    output [    BUF_CH-1:0] buf_select_o,
    input  [  2*BUF_CH-1:0] buf_ready_i ,   // [0]: ChA 0k-8k, [1]: ChA 8k-16k, [2]: ChB 0k-8k, [3]: ChB 8k-16k
    output [    BUF_AW-1:0] buf_raddr_o ,
    input  [    AXI_DW-1:0] buf_rdata_i ,

`ifndef DDRDUMP_WITH_SYSBUS
    // parameter export
    input       [   32-1:0] ddr_a_base  ,   // DDR ChA buffer base address
    input       [   32-1:0] ddr_a_end   ,   // DDR ChA buffer end address + 1
    output reg  [   32-1:0] ddr_a_curr  ,   // DDR ChA current write address
    input       [   32-1:0] ddr_b_base  ,   // DDR ChB buffer base address
    input       [   32-1:0] ddr_b_end   ,   // DDR ChB buffer end address + 1
    output reg  [   32-1:0] ddr_b_curr  ,   // DDR ChB current write address
    input       [    2-1:0] ddr_enable      // DDR dump enable flag A/B
`else
    // System bus
    input               sys_clk_i       ,   // bus clock
    input               sys_rstn_i      ,   // bus reset - active low
    input    [ 32-1: 0] sys_addr_i      ,   // bus saddress
    input    [ 32-1: 0] sys_wdata_i     ,   // bus write data
    input    [  4-1: 0] sys_sel_i       ,   // bus write byte select
    input               sys_wen_i       ,   // bus write enable
    input               sys_ren_i       ,   // bus read enable
    output   [ 32-1: 0] sys_rdata_o     ,   // bus read data
    output              sys_err_o       ,   // bus error indicator
    output              sys_ack_o           // bus acknowledge signal
`endif
);

localparam AXI_CW = 4;      // width of the ID expiry counters
localparam AXI_CI = 4'hf;   // initial countdown value for the ID expiry counters
genvar CNT;


// --------------------------------------------------------------------------------------------------
// set unused outputs to 0
assign  axi_araddr_o  = 32'd0;
assign  axi_arburst_o = 2'd0;
assign  axi_arcache_o = 4'd0;
assign  axi_arid_o    = 6'd0;
assign  axi_arlen_o   = 4'd0;
assign  axi_arlock_o  = 2'd0;
assign  axi_arprot_o  = 3'd0;
assign  axi_arqos_o   = 4'd0;
assign  axi_arsize_o  = 3'd0;
assign  axi_arvalid_o = 1'd0;
assign  axi_rready_o  = 1'd0;


// --------------------------------------------------------------------------------------------------
// set fixed transfer settings
assign  axi_awsize_o  = 3'b011;         // 8 bytes
assign  axi_awlen_o   = 4'b1111;        // 16 transfers
assign  axi_awburst_o = 2'b01;          // INCR
assign  axi_awcache_o = 4'b0001;        // bufferable, not cacheable
assign  axi_awprot_o  = 3'b000;         // normal, secure, data
assign  axi_awqos_o   = 4'd0;           // priority 0
assign  axi_awlock_o  = 2'b00;          // normal access
assign  axi_wstrb_o   = 8'b11111111;    // write all bytes


// --------------------------------------------------------------------------------------------------
// process ready latches from scope
reg  [ 4-1:0]   buf_ready;      // scope buffer ready registers Al,Ah,Bl,Bh
wire [ 4-1:0]   buf_finished;   // signals end of buffer processing Al,Ah,Bl,Bh
`ifdef DDRDUMP_WITH_SYSBUS
reg  [ 2-1:0]   ddr_enable;     // DDR dump enable flag A/B
`endif

always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        buf_ready <= 4'b0000;
    end else begin
        if (buf_ready_i[0]) begin
            buf_ready[0] <= ddr_enable[0];
        end else if (buf_finished[0]) begin
            buf_ready[0] <= 1'b0;
        end else begin
            buf_ready[0] <= buf_ready[0];
        end

        if (buf_ready_i[1]) begin
            buf_ready[1] <= ddr_enable[0];
        end else if (buf_finished[1]) begin
            buf_ready[1] <= 1'b0;
        end else begin
            buf_ready[1] <= buf_ready[1];
        end

        if (buf_ready_i[2]) begin
            buf_ready[2] <= ddr_enable[1];
        end else if (buf_finished[2]) begin
            buf_ready[2] <= 1'b0;
        end else begin
            buf_ready[2] <= buf_ready[2];
        end

        if (buf_ready_i[3]) begin
            buf_ready[3] <= ddr_enable[1];
        end else if (buf_finished[3]) begin
            buf_ready[3] <= 1'b0;
        end else begin
            buf_ready[3] <= buf_ready[3];
        end
    end
end


// --------------------------------------------------------------------------------------------------
// transfer BRAM data to AXI
reg  [       2-1:0] buf_sel;        // select signals for Cha / ChB
reg                 buf_sel_ab;     // stores the currently active channel
reg  [      12-1:0] buf_rp;         // BRAM read pointer
reg  [      32-1:0] ddr_wp;         // DDR write pointer
`ifdef DDRDUMP_WITH_SYSBUS
reg  [      32-1:0] ddr_a_base;     // DDR ChA buffer base address
reg  [      32-1:0] ddr_a_end;      // DDR ChA buffer end address + 1
reg  [      32-1:0] ddr_a_curr;     // DDR ChA current write address
reg  [      32-1:0] ddr_b_base;     // DDR ChB buffer base address
reg  [      32-1:0] ddr_b_end;      // DDR ChB buffer end address + 1
reg  [      32-1:0] ddr_b_curr;     // DDR ChB current write address
`endif
reg  [8*AXI_CW-1:0] ddr_id_cnt;     // write ID expiry counters ID0-7
reg                 tx_running;     // flag buffer transmission in progress
reg                 burst_running;  // flag burst in progress
reg  [  AXI_IW-1:0] ddr_curr_id;    // current write ID
reg                 ddr_aw_valid;   // flag next write address valid

// internal auxiliary signals
wire [       8-1:0] ddr_id_busy     = {|ddr_id_cnt[7*AXI_CW+:AXI_CW],|ddr_id_cnt[6*AXI_CW+:AXI_CW],|ddr_id_cnt[5*AXI_CW+:AXI_CW],|ddr_id_cnt[4*AXI_CW+:AXI_CW],
                                       |ddr_id_cnt[3*AXI_CW+:AXI_CW],|ddr_id_cnt[2*AXI_CW+:AXI_CW],|ddr_id_cnt[1*AXI_CW+:AXI_CW],|ddr_id_cnt[0*AXI_CW+:AXI_CW]};
wire                ddr_id_free     = (ddr_id_busy != 8'b11111111);
wire [      32-1:0] ddr_a_next      = ddr_a_curr + 32'h00004000;
wire [      32-1:0] ddr_b_next      = ddr_b_curr + 32'h00004000;
wire                ddr_burst_end   = axi_wready_i & (buf_rp[3:0] == 4'b1111);
wire                buf_end         = axi_wready_i & (buf_rp[10:0] == 11'b11111111111);
wire [       4-1:0] buf_newready;
wire                buf_pending     = |buf_newready;
wire                start_new_tx    = (!tx_running | buf_end) & ddr_id_free & buf_pending;
wire                start_new_burst = (start_new_tx | tx_running) & (!burst_running | (ddr_burst_end & buf_pending)) & ddr_id_free;
wire                hold_next_burst = ddr_burst_end & (!ddr_id_free | (buf_end & !buf_pending));

// --------------------------------------------------------------------------------------------------
// transaction and burst control
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        tx_running    <= 1'b0;
        burst_running <= 1'b0;
    end else begin
        if (start_new_tx) begin
            tx_running <= 1'b1;
        end else if (tx_running & buf_end & (!ddr_id_free | !buf_pending)) begin
            tx_running <= 1'b0;
        end else begin
            tx_running <= tx_running;
        end

        if (start_new_tx | start_new_burst) begin
            burst_running <= 1'b1;
        end else if (burst_running & hold_next_burst) begin
            burst_running <= 1'b0;
        end else begin
            burst_running <= burst_running;
        end
    end
end

assign  buf_finished[0] = tx_running & buf_end & ({buf_sel_ab,buf_rp[11]} == 2'b00);
assign  buf_finished[1] = tx_running & buf_end & ({buf_sel_ab,buf_rp[11]} == 2'b01);
assign  buf_finished[2] = tx_running & buf_end & ({buf_sel_ab,buf_rp[11]} == 2'b10);
assign  buf_finished[3] = tx_running & buf_end & ({buf_sel_ab,buf_rp[11]} == 2'b11);
assign  buf_newready[0] = buf_ready[0] & !buf_finished[0];
assign  buf_newready[1] = buf_ready[1] & !buf_finished[1];
assign  buf_newready[2] = buf_ready[2] & !buf_finished[2];
assign  buf_newready[3] = buf_ready[3] & !buf_finished[3];


// --------------------------------------------------------------------------------------------------
// BRAM control
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        buf_sel       <= 2'b00;
        buf_sel_ab    <= 1'b0;
        buf_rp        <= 12'h000;
    end else begin
        if (start_new_tx | start_new_burst) begin
            buf_sel <= (buf_newready[0] | buf_newready[1]) ? 2'b01 : 2'b10;
        end else if (burst_running & axi_wready_i & !hold_next_burst) begin
            buf_sel <= buf_sel_ab ? 2'b10 : 2'b01;
        end else begin
            buf_sel <= 2'b00;
        end

        if (start_new_tx) begin
            buf_rp <= (buf_newready[0] | (!buf_newready[1] & buf_newready[2])) ? 12'h000 : 12'h800;
        end else if ((burst_running & axi_wready_i & !hold_next_burst) | start_new_burst) begin
            buf_rp <= buf_rp + 1;
        end else begin
            buf_rp <= buf_rp;
        end

        if (start_new_tx) begin
            buf_sel_ab <= !(buf_newready[0] | buf_newready[1]);
        end else begin
            buf_sel_ab <= buf_sel_ab;
        end
    end
end

assign  buf_select_o = buf_sel;
assign  buf_raddr_o  = buf_rp;


// --------------------------------------------------------------------------------------------------
// AXI address control
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        ddr_wp        <= 32'h00000000;
        ddr_a_curr    <= ddr_a_base;
        ddr_b_curr    <= ddr_b_base;
        ddr_aw_valid  <= 1'b0;
    end else begin
        if (start_new_tx) begin
            ddr_wp <= (buf_newready[0] | buf_newready[1]) ? ddr_a_curr : ddr_b_curr;
        end else if ((burst_running & axi_wready_i & ddr_burst_end & !hold_next_burst) | start_new_burst) begin
            ddr_wp <= ddr_wp + 32'h80; // 128 bytes (16 qwords) per burst
        end else begin
            ddr_wp <= ddr_wp;
        end

        if (start_new_tx & (buf_newready[0] | buf_newready[1])) begin
            if (ddr_a_next >= ddr_a_end) begin
                ddr_a_curr <= ddr_a_base;
            end else begin
                ddr_a_curr <= ddr_a_next;
            end
        end else begin
            ddr_a_curr <= ddr_a_curr;
        end

        if (start_new_tx & !(buf_newready[0] | buf_newready[1])) begin
            if (ddr_b_next >= ddr_b_end) begin
                ddr_b_curr <= ddr_b_base;
            end else begin
                ddr_b_curr <= ddr_b_next;
            end
        end else begin
            ddr_b_curr <= ddr_b_curr;
        end

        if (start_new_tx | (burst_running & axi_wready_i & ddr_burst_end & !hold_next_burst) | start_new_burst) begin
            ddr_aw_valid <= 1'b1;
        end else if (ddr_aw_valid & axi_awready_i) begin
            ddr_aw_valid <= 1'b0;
        end else begin
            ddr_aw_valid <= ddr_aw_valid;
        end
    end
end

assign  axi_awaddr_o  = ddr_wp;
assign  axi_awvalid_o = ddr_aw_valid;
assign  axi_wdata_o   = buf_rdata_i;
assign  axi_wlast_o   = (buf_rp[3:0] == 4'b1111); // fixed 16 beat burst
assign  axi_wvalid_o  = burst_running;
assign  axi_bready_o  = 1'd1;


// --------------------------------------------------------------------------------------------------
// AXI ID control
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        ddr_curr_id   <= 0;
    end else begin
        if (start_new_tx | (burst_running & axi_wready_i & ddr_burst_end & !hold_next_burst) | start_new_burst) begin
            casex (ddr_id_busy)
            8'b???????0:    begin   ddr_curr_id <= 0;           end
            8'b??????01:    begin   ddr_curr_id <= 1;           end
            8'b?????011:    begin   ddr_curr_id <= 2;           end
            8'b????0111:    begin   ddr_curr_id <= 3;           end
            8'b???01111:    begin   ddr_curr_id <= 4;           end
            8'b??011111:    begin   ddr_curr_id <= 5;           end
            8'b?0111111:    begin   ddr_curr_id <= 6;           end
            8'b01111111:    begin   ddr_curr_id <= 7;           end
            8'b11111111:    begin   ddr_curr_id <= ddr_curr_id; end
            endcase
        end else begin
            ddr_curr_id <= ddr_curr_id;
        end
    end
end

assign  axi_awid_o = ddr_curr_id;
assign  axi_wid_o  = ddr_curr_id;

// generate expiry counter logic
generate for (CNT=0; CNT<8; CNT=CNT+1) begin: expiry_counter if (CNT == 0) begin

// counter 0
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= 0;
    end else begin
        if (!ddr_id_busy[CNT] & 
            (start_new_tx | (burst_running & axi_wready_i & ddr_burst_end & !hold_next_burst) | start_new_burst)) begin
            ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= AXI_CI;
        end else if (axi_bvalid_i & (axi_bid_i == CNT)) begin
            ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= 0;
        end else if (ddr_id_busy[CNT]) begin
            if (burst_running & (ddr_curr_id == CNT)) begin
                ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= AXI_CI;
            end else begin
                ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= ddr_id_cnt[CNT*AXI_CW+:AXI_CW] - 1;
            end
        end else begin
            ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= ddr_id_cnt[CNT*AXI_CW+:AXI_CW];
        end
    end
end

end else begin // elsegenerate

// counter x
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= 0;
    end else begin
        if (&ddr_id_busy[CNT-1:0] & !ddr_id_busy[CNT] & 
            (start_new_tx | (burst_running & axi_wready_i & ddr_burst_end & !hold_next_burst) | start_new_burst)) begin
            ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= AXI_CI;
        end else if (axi_bvalid_i & (axi_bid_i == CNT)) begin
            ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= 0;
        end else if (ddr_id_busy[CNT]) begin
            if (burst_running & (ddr_curr_id == CNT)) begin
                ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= AXI_CI;
            end else begin
                ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= ddr_id_cnt[CNT*AXI_CW+:AXI_CW] - 1;
            end
        end else begin
            ddr_id_cnt[CNT*AXI_CW+:AXI_CW] <= ddr_id_cnt[CNT*AXI_CW+:AXI_CW];
        end
    end
end

end end endgenerate


`ifdef DDRDUMP_WITH_SYSBUS
// --------------------------------------------------------------------------------------------------
// system bus connection
wire [32-1:0]   addr;
wire [32-1:0]   wdata;
wire            wen;
wire            ren;
reg  [32-1:0]   rdata;
reg             err;
reg             ack;


// --------------------------------------------------------------------------------------------------
// reset / write
always @(posedge buf_clk_i) begin
    if (!buf_rstn_i) begin
        ddr_a_base <= 32'h00000000;
        ddr_a_end  <= 32'h00000000;
        ddr_b_base <= 32'h00000000;
        ddr_b_end  <= 32'h00000000;
        ddr_enable <= 2'b00;
    end else begin
        if (wen) begin
            if (addr[19:0] == 20'h00)   begin   ddr_enable <= wdata[32-2+:2];   end

            if (addr[19:0] == 20'h10)   begin   ddr_a_base <= {wdata[32-1:12],12'h000}; end
            if (addr[19:0] == 20'h14)   begin   ddr_a_end  <= {wdata[32-1:12],12'h000}; end
            if (addr[19:0] == 20'h18)   begin   ddr_b_base <= {wdata[32-1:12],12'h000}; end
            if (addr[19:0] == 20'h1c)   begin   ddr_b_end  <= {wdata[32-1:12],12'h000}; end
        end
    end
end


// --------------------------------------------------------------------------------------------------
// read
always @(*) begin
    err <= 1'b0;

    if (addr[19:0] == 20'h00)   begin   ack <= 1'b1;    rdata <= {ddr_enable,30'h0};    end

    if (addr[19:0] == 20'h08)   begin   ack <= 1'b1;    rdata <= ddr_a_curr;    end
    if (addr[19:0] == 20'h0c)   begin   ack <= 1'b1;    rdata <= ddr_b_curr;    end

    if (addr[19:0] == 20'h10)   begin   ack <= 1'b1;    rdata <= ddr_a_base;    end
    if (addr[19:0] == 20'h14)   begin   ack <= 1'b1;    rdata <= ddr_a_end;     end
    if (addr[19:0] == 20'h18)   begin   ack <= 1'b1;    rdata <= ddr_b_base;    end
    if (addr[19:0] == 20'h1c)   begin   ack <= 1'b1;    rdata <= ddr_b_end;     end
end


// --------------------------------------------------------------------------------------------------
// bridge between Dumper and sys clock
bus_clk_bridge i_bridge
(
    .sys_clk_i      (sys_clk_i      ),
    .sys_rstn_i     (sys_rstn_i     ),
    .sys_addr_i     (sys_addr_i     ),
    .sys_wdata_i    (sys_wdata_i    ),
    .sys_sel_i      (sys_sel_i      ),
    .sys_wen_i      (sys_wen_i      ),
    .sys_ren_i      (sys_ren_i      ),
    .sys_rdata_o    (sys_rdata_o    ),
    .sys_err_o      (sys_err_o      ),
    .sys_ack_o      (sys_ack_o      ),

    .clk_i          (buf_clk_i      ),
    .rstn_i         (buf_rstn_i     ),
    .addr_o         (addr           ),
    .wdata_o        (wdata          ),
    .wen_o          (wen            ),
    .ren_o          (ren            ),
    .rdata_i        (rdata          ),
    .err_i          (err            ),
    .ack_i          (ack            )
);
`endif


endmodule
