`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
import wishbone_pkg::*;

module ddbb32_config(rst_i, clk_i, irq_i, cs_i, resp_busy_i, req_i, resp_o,
	cs_bar0_o, cs_bar1_o, cs_bar2_o, irq_chain_i, irq_chain_o);
input rst_i;
input clk_i;
input [3:0] irq_i;
input cs_i;
input resp_busy_i;
input wb_cmd_request32_t req_i;
output wb_cmd_response32_t resp_o;
output reg cs_bar0_o;
output reg cs_bar1_o;
output reg cs_bar2_o;
input [15:0] irq_chain_i;
output reg [15:0] irq_chain_o;

parameter pDevName = "UNKNOWN     ";

parameter CFG_BUS = 6'd0;
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

parameter CFG_ROM_FILENAME = "ddbb32_config.mem";

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;
parameter NIRQ = 0;
parameter ROM = 0;

integer n1,n2,n3,n4;
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
fta_cmd_response64_t irq_resp;
fta_imessage_t irq_resp2, irq_resp1;
wire cs_config_i;
reg [NIRQ-1:0] irq_req;
reg [NIRQ-1:0] irq_i2;

// IRQ FIFO signals
wire rst = rst_i;
wire wr_clk = clk_i;
reg rd_en,wr_en,rd_en1,wr_en1;
reg irq_sleep;
wire rd_rst_busy,wr_rst_busy;
wire data_valid;
wire empty;

// RAM / ROM signals
wire rsta = rst_i;
wire clka = clk_i;
wire [3:0] wea = {4{req_i.we & cs_config_i}} && req_i.sel && req_i.adr[13:9]==5'd0;
wire ena = 1'b1;
wire [11:0] addra = req_i.adr[13:2];
wire [31:0] dina = req_i.dat;
wire [31:0] douta;

reg [31:0] dato;

wire cs = cs_config_i;

function [31:0] fnRbo32;
input [31:0] i;
begin
	fnRbo32 = {i[7:0],i[15:8],i[23:16],i[31:24]};
end
endfunction

// FTA bus interface
wire rd_ack, wr_ack;
wire [31:0] adr3;
fta_asid_t asid3;
fta_tranid_t tid3;
wire [3:0] sel_i = req_i.sel;
wire [31:0] dat_i = req_i.adr[13:0] < 14'h0200 ? (req_i.adr[8] ? fnRbo32(req_i.dat) : req_i.dat) : req_i.dat;
wire [31:0] adr_i = req_i.adr;

assign cs_config_i = cs_i && req_i.cyc &&
		req_i.adr[27:22]==CFG_BUS &&
		req_i.adr[21:17]==CFG_DEVICE &&
		req_i.adr[16:14]==CFG_FUNC;

vtdl #(.WID(1), .DEP(16)) udlyc (.clk(clk_i), .ce(1'b1), .a(0), .d(cs & ~req_i.we), .q(rd_ack));
vtdl #(.WID(1), .DEP(16)) udlyw (.clk(clk_i), .ce(1'b1), .a(0), .d(cs &  req_i.we), .q(wr_ack));
always_comb
	resp_o.ack <= (rd_ack|wr_ack);

vtdl #(.WID($bits(fta_tranid_t)), .DEP(16)) udlytid (.clk(clk_i), .ce(1'b1), .a(0), .d(req_i.tid), .q(tid3));
vtdl #(.WID(32), .DEP(16)) udlyadr (.clk(clk_i), .ce(1'b1), .a(0), .d(req_i.adr), .q(adr3));
always_ff @(posedge clk_i)
if (resp_o.ack) begin
	resp_o.tid <= tid3;
	resp_o.adr <= adr3;
	if (adr3[13:0] < 14'h0200)
		resp_o.dat <= adr3[8] ? fnRbo32(dato) : dato;
	else
		resp_o.dat <= dato;
	resp_o.err = fta_bus_pkg::OKAY;
end
else begin
	resp_o.tid <= 13'd0;
	resp_o.adr <= 32'd0;
	resp_o.err = fta_bus_pkg::OKAY;
end
always_comb resp_o.next = 1'd0;
always_comb resp_o.stall = 1'd0;
always_comb resp_o.rty = 1'd0;
always_comb resp_o.pri = 4'd7;

reg [15:0] irq_vect [0:3];

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
	stato_reg[3] = |irq_i;	// interrupt status
	stato_reg[4] = 1'b0;		// capabilities list
	stato_reg[5] = 1'b1;		// 66 MHz enable (N/A)
	stato_reg[6] = 1'b0;		// reserved
	stato_reg[7] = 1'b1;		// fast back-to-back capable
	stato_reg[10:9] = 2'b01;	// medium DEVSEL timing
end

reg [31:0] cfg_dat [0:63];

initial begin
	for (n1 = 0; n1 < 64; n1 = n1 + 1)
		cfg_dat[n1] = 'd0;
end

always_ff @(posedge clk_i)
if (rst_i) begin
	sleep <= FALSE;
	bar0 <= CFG_BAR0;
	bar1 <= CFG_BAR1;
	bar2 <= CFG_BAR2;
	cmd_reg <= 16'h4003;
	stat_reg <= 16'h0000;
	irq_req <= 4'b0;
	irq_vect[0] <= 16'd0;
	irq_vect[1] <= 16'd0;
	irq_vect[2] <= 16'd0;
	irq_vect[3] <= 16'd0;
end
else begin
	io_space <= cmdo_reg[0];
	memory_space <= cmdo_reg[1];
	bus_master <= cmdo_reg[2];
	parity_err_resp <= cmdo_reg[6];
	serr_enable <= cmdo_reg[8];
	int_disable <= cmdo_reg[10];
	for (n4 = 0; n4 < NIRQ; n4 = n4 + 1)
		if (irqf[n4] & ~irq_i2[n4])
			irq_req[n4] <= 1'b0;

	if (cs) begin
		if (req_i.we)
			casez(req_i.adr[13:2])
			12'h02:
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
			12'h04:
				begin
					if (&sel_i[3:0] && dat_i[31:0]==32'hFFFFFFFF)
						bar0 <= CFG_BAR0_MASK;
					else begin
						if (sel_i[0])	bar0[7:0] <= dat_i[7:0];
						if (sel_i[1])	bar0[15:8] <= dat_i[15:8];
						if (sel_i[2])	bar0[23:16] <= dat_i[23:16];
						if (sel_i[3])	bar0[31:24] <= dat_i[31:24];
					end
				end
			12'h05:
				if (&sel_i[3:0] && dat_i[31:0]==32'hFFFFFFFF)
					bar1 <= CFG_BAR1_MASK;
				else begin
					if (sel_i[0])	bar1[7:0] <= dat_i[7:0];
					if (sel_i[1])	bar1[15:8] <= dat_i[15:8];
					if (sel_i[2])	bar1[23:16] <= dat_i[23:16];
					if (sel_i[3])	bar1[31:24] <= dat_i[31:24];
				end
			12'h06:
				if (&sel_i[3:0] && dat_i[31:0]==32'hFFFFFFFF)
					bar2 <= CFG_BAR2_MASK;
				else begin
					if (sel_i[0])	bar2[7:0] <= dat_i[7:0];
					if (sel_i[1])	bar2[15:8] <= dat_i[15:8];
					if (sel_i[2])	bar2[23:16] <= dat_i[23:16];
					if (sel_i[3])	bar2[31:24] <= dat_i[31:24];
				end
			// IRQ bus controls
			12'h010:	if (&sel_i[3:0]) irq_vect[0] <= dat_i;
			12'h011:	if (&sel_i[3:0]) irq_vect[1] <= dat_i;
			12'h012:	if (&sel_i[3:0]) irq_vect[2] <= dat_i;
			12'h013:	if (&sel_i[3:0]) irq_vect[3] <= dat_i;
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
			casez(req_i.adr[13:2])
			12'h000:	dato <= {CFG_DEVICE_ID,CFG_VENDOR_ID};
			12'h001:	dato <= {stato_reg,cmdo_reg};
			12'h002:	dato <= {CFG_CLASS,CFG_SUBCLASS,CFG_PROGIF,CFG_REVISION_ID};
			12'h003:	dato <= {8'h00,CFG_HEADER_TYPE,latency_timer,CFG_CACHE_LINE_SIZE};
			12'h004:	dato <= bar0;
			12'h005:	dato <= bar1;
			12'h006:	dato <= bar2;
			12'h007:	dato <= 32'hFFFFFFFF;
			12'h008:	dato <= 32'hFFFFFFFF;
			12'h009:	dato <= 32'hFFFFFFFF;
			12'h00A:	dato <= 32'h0;
			12'h00B:	dato <= {CFG_SUBSYSTEM_ID,CFG_SUBSYSTEM_VENDOR_ID};
			12'h00C:	dato <= CFG_ROM_ADDR;
			12'h00D:	dato <= 32'h0;
			12'h010:	dato <= irq_vect[0];
			12'h011:	dato <= irq_vect[1];
			12'h012:	dato <= irq_vect[2];
			12'h013:	dato <= irq_vect[3];
			12'h020:	dato <= pDevName[31: 0];
			12'h021:	dato <= pDevName[63:32];
			12'h022:	dato <= pDevName[95:64];
			12'h023:	dato <= 32'd0;
			default:	dato <= douta;
			endcase
	end
end

// Trigger IRQ message if IRQ signal set.

wire irq_chain_empty = irq_chain_i==16'd0;

reg [3:0] irq_wr;
always_ff @(posedge clk_i)
if (rst_i) begin
	irqf <= 4'h0;
	irq_i2 <= 4'h0;
end
else begin
	irq_chain_o <= irq_chain_i;
	for (n2 = 0; n2 < NIRQ; n2 = n2 + 1) begin
		irq_i2[n2] <= irq_i[n2];
		if (irq_i[n2]|irq_req[n2])
			irqf[n2] <= irq_timer[n2]==6'h3F;
	end
	if (irqf[0] && irq_chain_empty) begin
		irqf[0] <= FALSE;
		irq_chain_o <= irq_vect[0];
	end
	else if (irqf[1] && irq_chain_empty) begin
		irqf[1] <= FALSE;
		irq_chain_o <= irq_vect[1];
	end
	else if (irqf[2] && irq_chain_empty) begin
		irqf[2] <= FALSE;
		irq_chain_o <= irq_vect[2];
	end
	else if (irqf[3] && irq_chain_empty) begin
		irqf[3] <= FALSE;
		irq_chain_o <= irq_vect[3];
	end
end

// This timer to prevent an IRQ from recurring in subsequent cycles.

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

always_comb
	cs_bar0_o = req_i.cyc && ((req_i.adr ^ bar0) & CFG_BAR0_MASK) == 32'd0;
always_comb
	cs_bar1_o = req_i.cyc && ((req_i.adr ^ bar1) & CFG_BAR1_MASK) == 32'd0;
always_comb
	cs_bar2_o = req_i.cyc && ((req_i.adr ^ bar2) & CFG_BAR2_MASK) == 32'd0;


generate begin : gROM			
// XPM_MEMORY instantiation template for Single Port RAM configurations
// Refer to the targeted device family architecture libraries guide for XPM_MEMORY documentation
// =======================================================================================================================

   // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2
if (ROM)
   xpm_memory_spram #(
      .ADDR_WIDTH_A(10),             // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       	// DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE(CFG_ROM_FILENAME),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(32*1024),          // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(32),       // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(32),       // DECIMAL
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
