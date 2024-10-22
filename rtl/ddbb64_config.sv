`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//		
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 390 LUTs / 590 FFs / 1 BRAM
// 220 LUTs / 360 FFs / 0 BRAM		(no ROM or IRQ)
// ============================================================================
//
import const_pkg::*;
import fta_bus_pkg::*;

module ddbb64_config(rst_i, clk_i, irq_i, cs_i, req_i, resp_o,
	cs_bar0_o, cs_bar1_o, cs_bar2_o);
input rst_i;
input clk_i;
input [1:0] irq_i;
input cs_i;
input fta_cmd_request64_t req_i;
output fta_cmd_response64_t resp_o;
output reg cs_bar0_o;
output reg cs_bar1_o;
output reg cs_bar2_o;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd0;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_BAR0 = 32'h1;
parameter CFG_BAR1 = 32'h1;
parameter CFG_BAR2 = 32'h1;
parameter CFG_BAR0_MASK = 32'h0;
parameter CFG_BAR1_MASK = 32'h0;
parameter CFG_BAR2_MASK = 32'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h80;					// 80 = Other
parameter CFG_CLASS = 8'h03;						// 03 = display controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd16;
parameter CFG_IRQ_DEVICE = 8'd0;
parameter CFG_IRQ_CORE = 6'd0;
parameter CFG_IRQ_CHANNEL = 3'd0;
parameter CFG_IRQ_PRIORITY = 4'd10;
parameter CFG_IRQ_CAUSE = 8'd0;

parameter CFG_ROM_FILENAME = "ddbb64_config.mem";

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;
parameter ROM = 0;
parameter NIRQ = 0;

integer n1,n2,n3;
reg sleep;								// put ROM to sleep
reg [31:0] bar0;
reg [31:0] bar1;
reg [31:0] bar2;
reg [15:0] cmd_reg;
reg [15:0] cmdo_reg;
reg memory_space, io_space;
reg bus_master;
reg parity_err_resp;
reg serr_enable;
reg int_disable;
reg [7:0] latency_timer = 8'h00;
reg [NIRQ-1:0] irqf;
reg [5:0] irq_timer [0:NIRQ-1];
fta_cmd_response32_t irq_resp, irq_resp1;
wire cs_config_i;

// IRQ FIFO signals
wire rst = rst_i;
wire wr_clk = clk_i;
reg rd_en,wr_en,rd_en1,wr_en1;
reg irq_sleep;
wire rd_rst_busy,wr_rst_busy;
wire data_valid;

// RAM / ROM signals
wire rsta = rst_i;
wire clka = clk_i;
wire [7:0] wea = {8{req_i.we & cs_config_i}} && req_i.sel && req_i.padr[11:9]==3'd0;
wire ena = 1'b1;
wire [9:0] addra = req_i.padr[11:2];
wire [63:0] dina = req_i.dat;
wire [63:0] douta;

reg [63:0] dat_o;

// FTA bus interface
wire rd_ack, wr_ack;
wire [31:0] adr3;
fta_asid_t asid3;
fta_tranid_t tid3;
wire [3:0] sel_i = req_i.sel;
wire [31:0] dat_i = req_i.dat;
wire [31:0] adr_i = req_i.padr;

assign cs_config_i = cs_i && req_i.cyc &&
		req_i.padr[27:20]==CFG_BUS &&
		req_i.padr[19:15]==CFG_DEVICE &&
		req_i.padr[14:12]==CFG_FUNC;

assign resp_o.dat = dat_o;
wire erc = req_i.cti==ERC;

vtdl #(.WID(1), .DEP(16)) udlyc (.clk(clk_i), .ce(1'b1), .a(2), .d((cs_config_i & ~req_i.we) | rd_en), .q(rd_ack));
vtdl #(.WID(1), .DEP(16)) udlyw (.clk(clk_i), .ce(1'b1), .a(2), .d(cs_config_i &  req_i.we & erc), .q(wr_ack));
always_ff @(posedge clk_i)
	resp_o.ack <= (rd_ack|wr_ack);

vtdl #(.WID($bits(fta_asid_t)), .DEP(16)) udlyasid (.clk(clk_i), .ce(1'b1), .a(2), .d(rd_en ? 16'h0 : req_i.asid), .q(asid3));
vtdl #(.WID($bits(fta_tranid_t)), .DEP(16)) udlytid (.clk(clk_i), .ce(1'b1), .a(2), .d(rd_en ? irq_resp.tid : req_i.tid), .q(tid3));
vtdl #(.WID(32), .DEP(16)) udlyadr (.clk(clk_i), .ce(1'b1), .a(2), .d(rd_en ? irq_resp.adr : req_i.padr), .q(adr3));
always_ff @(posedge clk_i)
	resp_o.asid <= asid3;
always_ff @(posedge clk_i)
	resp_o.tid <= tid3;
always_ff @(posedge clk_i)
	resp_o.adr <= adr3;
always_comb resp_o.next = 1'd0;
always_comb resp_o.stall = 1'd0;
always_comb resp_o.err = fta_bus_pkg::OKAY;
always_comb resp_o.rty = 1'd0;
always_comb resp_o.pri = 4'd7;

typedef struct packed {
	logic [12:0] resv;
	logic [2:0] pri;
	// target
	logic [2:0] resvt;
	fta_tranid_t tid;
	// source
	logic [7:0] resvs;
	logic [7:0] cause;
	logic [7:0] bus;
	logic [4:0] device;
	logic [2:0] func;
} irq_info_t;

irq_info_t [7:0] irq_info;

always_comb
begin
	cmdo_reg = cmd_reg;
	cmdo_reg[3] = 1'b0;			// no special cycles
	cmdo_reg[4] = 1'b0;			// memory write and invalidate supported
	cmdo_reg[5] = 1'b0;			// VGA palette snoop
	cmdo_reg[7] = 1'b0;			// reserved bit
	cmdo_reg[9] = 1'b1;			// fast back-to-back enable
	cmdo_reg[15:11] = 5'd0;	// reserved
end

reg [15:0] stat_reg;
reg [15:0] stato_reg;
always_comb
begin
	stato_reg = stat_reg;
	stato_reg[2:0] = 3'b0;	// reserved
	stato_reg[3] = irq_i;		// interrupt status
	stato_reg[4] = 1'b0;		// capabilities list
	stato_reg[5] = 1'b1;		// 66 MHz enable (N/A)
	stato_reg[6] = 1'b0;		// reserved
	stato_reg[7] = 1'b1;		// fast back-to-back capable
	stato_reg[10:9] = 2'b01;	// medium DEVSEL timing
end

reg [31:0] cfg_dat [0:63];
reg [7:0] irq_line;

initial begin
	for (n1 = 0; n1 < 64; n1 = n1 + 1)
		cfg_dat[n1] = 'd0;
end

wire cs = cs_config_i;

always_ff @(posedge clk_i)
if (rst_i) begin
	sleep <= FALSE;
	bar0 <= CFG_BAR0;
	bar1 <= CFG_BAR1;
	bar2 <= CFG_BAR2;
	cmd_reg <= 16'h4003;
	stat_reg <= 16'h0000;
end
else begin
	io_space <= cmdo_reg[0];
	memory_space <= cmdo_reg[1];
	bus_master <= cmdo_reg[2];
	parity_err_resp <= cmdo_reg[6];
	serr_enable <= cmdo_reg[8];
	int_disable <= cmdo_reg[10];

	if (cs) begin
		if (req_i.we)
			case(req_i.padr[11:3])
			9'h01:
				begin
					if (sel_i[0]) cmd_reg[7:0] <= dat_i[7:0];
					if (sel_i[1]) cmd_reg[15:8] <= dat_i[15:8];
					if (sel_i[3]) begin
						if (dat_i[8]) stat_reg[8] <= 1'b0;
						if (dat_i[11]) stat_reg[11] <= 1'b0;
						if (dat_i[12]) stat_reg[12] <= 1'b0;
						if (dat_i[13]) stat_reg[13] <= 1'b0;
						if (dat_i[14]) stat_reg[14] <= 1'b0;
						if (dat_i[15]) stat_reg[15] <= 1'b0;
					end
				end
			9'h02:
				begin
					if (&sel_i[3:0] && dat_i[31:0]==32'hFFFFFFFF)
						bar0 <= CFG_BAR0_MASK;
					else begin
						if (sel_i[0])	bar0[7:0] <= dat_i[7:0];
						if (sel_i[1])	bar0[15:8] <= dat_i[15:8];
						if (sel_i[2])	bar0[23:16] <= dat_i[23:16];
						if (sel_i[3])	bar0[31:24] <= dat_i[31:24];
					end
					if (&sel_i[7:4] && dat_i[63:32]==32'hFFFFFFFF)
						bar1 <= CFG_BAR1_MASK;
					else begin
						if (sel_i[0])	bar1[7:0] <= dat_i[39:32];
						if (sel_i[1])	bar1[15:8] <= dat_i[47:40];
						if (sel_i[2])	bar1[23:16] <= dat_i[55:48];
						if (sel_i[3])	bar1[31:24] <= dat_i[63:56];
					end
				end
			9'h03:
				if (&sel_i[3:0] && dat_i[31:0]==32'hFFFFFFFF)
					bar2 <= CFG_BAR2_MASK;
				else begin
					if (sel_i[0])	bar2[7:0] <= dat_i[7:0];
					if (sel_i[1])	bar2[15:8] <= dat_i[15:8];
					if (sel_i[2])	bar2[23:16] <= dat_i[23:16];
					if (sel_i[3])	bar2[31:24] <= dat_i[31:24];
				end
			// IRQ bus controls
			9'h8:	
				begin
					if (&sel_i[3:0]) irq_info[3'd0][31: 0] <= dat_i[31: 0];
					if (&sel_i[7:4]) irq_info[3'd0][63:32] <= dat_i[63:32];
				end
			9'h9:
				begin
					if (&sel_i[3:0]) irq_info[3'd1][31: 0] <= dat_i[31: 0];
					if (&sel_i[7:4]) irq_info[3'd1][63:32] <= dat_i[63:32];
				end
			/*
			10'h14:	if (&sel_i[3:0]) irq_info[3'd2][31:0] <= dat_i;
			10'h15:	if (&sel_i[3:0]) irq_info[3'd2][63:32] <= dat_i;
			10'h16:	if (&sel_i[3:0]) irq_info[3'd3][31:0] <= dat_i;
			10'h17:	if (&sel_i[3:0]) irq_info[3'd3][63:32] <= dat_i;
			*/
			default:
				;
			endcase
		else
			case(adr_i[11:3])
			9'h00:
				begin
					dat_o[31: 0] <= {CFG_DEVICE_ID,CFG_VENDOR_ID};
					dat_o[63:32] <= {stato_reg,cmdo_reg};
				end
			9'h01:
				begin
					dat_o[31: 0] <= {CFG_CLASS,CFG_SUBCLASS,CFG_PROGIF,CFG_REVISION_ID};
					dat_o[63:32] <= {8'h00,CFG_HEADER_TYPE,latency_timer,CFG_CACHE_LINE_SIZE};
				end
			9'h02:
				begin
					dat_o[31: 0] <= bar0;
					dat_o[63:32] <= bar1;
				end
			9'h03:
				begin
					dat_o[31: 0] <= bar2;
					dat_o[63:32] <= 32'hFFFFFFFF;
				end
			9'h04:
				begin
					dat_o[31: 0] <= 32'hFFFFFFFF;
					dat_o[63:32] <= 32'hFFFFFFFF;
				end
			9'h05:
				begin
					dat_o[31: 0] <= 32'h0;
					dat_o[63:32] <= {CFG_SUBSYSTEM_ID,CFG_SUBSYSTEM_VENDOR_ID};
				end
			9'h06:
				begin
					dat_o[31: 0] <= CFG_ROM_ADDR;
					dat_o[63:32] <= 32'h0;
				end
			9'h08:
				begin
					dat_o[31: 0] <= irq_info[3'd0][31: 0];
					dat_o[63:32] <= irq_info[3'd0][63:32];
				end
			9'h09:
				begin
					dat_o[31: 0] <= irq_info[3'd1][31: 0];
					dat_o[63:32] <= irq_info[3'd1][63:32];
				end
			/*
			10'h14:	dat_o <= irq_info[3'd2][31:0];
			10'h15:	dat_o <= irq_info[3'd2][63:32];
			10'h16:	dat_o <= irq_info[3'd3][31:0];
			10'h17:	dat_o <= irq_info[3'd3][63:32];
			*/
			default:	dat_o <= douta;
			endcase
	end
end

always_ff @(posedge clk_i)
if (rst_i) begin
	irq_sleep <= FALSE;
	irqf <= 8'h00;
	irq_resp.rty <= FALSE;
	irq_resp.err <= fta_bus_pkg::OKAY;
	irq_resp.adr <= 32'hFFFFFFFF;
end
else begin
	irq_resp1.ack <= FALSE;
	for (n2 = 0; n2 < NIRQ; n2 = n2 + 1)
		if (irq_i[n2])
			irqf[n2] <= irq_timer[n2]==6'h3F;
	if (irqf[0]) begin
		irqf[0] <= FALSE;
		irq_resp1.ack <= TRUE;
		irq_resp1.dat <= irq_info[3'd0][31:0];
		irq_resp1.tid <= irq_info[3'd0].tid;
		irq_resp1.pri <= irq_info[3'd0].pri;
	end
	else if (irqf[1]) begin
		irqf[1] <= FALSE;
		irq_resp1.ack <= TRUE;
		irq_resp1.dat <= irq_info[3'd1][31:0];
		irq_resp1.tid <= irq_info[3'd1].tid;
		irq_resp1.pri <= irq_info[3'd1].pri;
	end
	/*
	else if (irqf[2]) begin
		irqf[2] <= FALSE;
		irq_resp1.ack <= TRUE;
		irq_resp1.dat <= irq_info[3'd2][31:0];
		irq_resp1.tid <= irq_info[3'd2].tid;
		irq_resp1.pri <= irq_info[3'd2].pri;
	end
	else if (irqf[3]) begin
		irqf[3] <= FALSE;
		irq_resp1.ack <= TRUE;
		irq_resp1.dat <= irq_info[3'd3][31:0];
		irq_resp1.tid <= irq_info[3'd3].tid;
		irq_resp1.pri <= irq_info[3'd3].pri;
	end
	*/
end

always_ff @(posedge clk_i)
if (rst_i) begin
	for (n3 = 0; n3 < NIRQ; n3 = n3 + 1)
		irq_timer[n3] <= 6'h3F;
end
else begin
	for (n3 = 0; n3 < NIRQ; n3 = n3 + 1) begin
		if (irq_timer[n3]!=6'h3F)
			irq_timer[n3] <= irq_timer[n3] + 2'd1;
		if (irqf[n3])
			irq_timer[n3] <= 6'h00;
	end
end

always_ff @(posedge clk_i)
if (rst|wr_rst_busy|rd_rst_busy)
	wr_en1 <= 1'b0;
else
	wr_en1 <= irq_resp1.ack;
always_comb wr_en = wr_en1 & ~(rst|wr_rst_busy|rd_rst_busy);

always_comb rd_en = irq_resp.ack & data_valid & ~(rst|wr_rst_busy|rd_rst_busy|cs_config_i);

//always_comb
//	irq_o = {irq_device,2'd0,irq_core,1'b0,irq_channel,irq_priority,cause_code};
//	irq_o = {31'd0,irq_i & ~int_disable} << irq_line;

always_comb
	cs_bar0_o = req_i.cyc && ((req_i.padr ^ bar0) & CFG_BAR0_MASK) == 32'd0;
always_comb
	cs_bar1_o = req_i.cyc && ((req_i.padr ^ bar1) & CFG_BAR1_MASK) == 32'd0;
always_comb
	cs_bar2_o = req_i.cyc && ((req_i.padr ^ bar2) & CFG_BAR2_MASK) == 32'd0;


generate begin : gIRQFifo
	
// XPM_FIFO instantiation template for Synchronous FIFO configurations
// Refer to the targeted device family architecture libraries guide for XPM_FIFO documentation
// =======================================================================================================================

   // xpm_fifo_sync: Synchronous FIFO
   // Xilinx Parameterized Macro, version 2022.2
if (NIRQ > 0)
   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("distributed"), // String
      .FIFO_READ_LATENCY(0),     // DECIMAL
      .FIFO_WRITE_DEPTH(32),   	 // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
      .READ_DATA_WIDTH($bits(fta_cmd_response64_t)),      // DECIMAL
      .READ_MODE("fwft"),         // String
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("1707"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH($bits(fta_cmd_response64_t)),     // DECIMAL
      .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
   )
   xpm_fifo_sync_inst (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(data_valid),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(irq_resp),              // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(), 		                // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(),		                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(),				           // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),					       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),					         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(), 						// RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),             			// 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(),					         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),			               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(),							 // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(irq_resp1),               // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(1'b0), 				// 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(1'b0), 				// 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_en(rd_en),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(irq_sleep),            	// 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(wr_clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(wr_en)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO Must be held
                                     // active-low when rst or wr_rst_busy or rd_rst_busy is active high

   );
end
endgenerate
				

generate begin : gROM			
// XPM_MEMORY instantiation template for Single Port RAM configurations
// Refer to the targeted device family architecture libraries guide for XPM_MEMORY documentation
// =======================================================================================================================

   // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2
if (ROM)
   xpm_memory_spram #(
      .ADDR_WIDTH_A(9),             // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       	// DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE(CFG_ROM_FILENAME),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(64*512),          // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(64),       // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(64),       // DECIMAL
      .WRITE_MODE_A("read_first"),   // String
      .WRITE_PROTECT(1)              // DECIMAL
   )
   xpm_memory_spram_inst (
      .dbiterra(),	 				          // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .sbiterra(),				             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A.
      .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), 					// 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), 					// 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),	                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );
end
endgenerate

endmodule
