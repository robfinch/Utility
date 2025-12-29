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

module ddbb64_config(rst_i, clk_i, irq_i, cs_i, resp_busy_i, req_i, resp_o,
	irq_chain_i, irq_chain_o, cs_bar0_o, cs_bar1_o, cs_bar2_o);
input rst_i;
input clk_i;
input [3:0] irq_i;
input cs_i;
input resp_busy_i;
input wb_cmd_request64_t req_i;
output wb_cmd_response64_t resp_o;
input [15:0] irq_chain_i;
output reg [15:0] irq_chain_o;
output reg cs_bar0_o;
output reg cs_bar1_o;
output reg cs_bar2_o;

parameter pDevName = "UNKNOWN         ";
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

parameter CFG_ROM_FILENAME = "ddbb64_config.mem";

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device
parameter BUS_PROTOCOL = 0;

parameter MSIX = 1'b0;
parameter NIRQ = 0;
parameter ROM = 0;

integer n1,n2,n3,n4;
reg sleep;								// put ROM to sleep
reg [15:0] tid_o;
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
wb_cmd_response64_t irq_resp;
wb_imessage_t irq_resp2, irq_resp1;
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
wire [7:0] wea = {8{req_i.we & cs_config_i}} && req_i.sel && req_i.adr[13:9]==5'd0;
wire ena = 1'b1;
wire [10:0] addra = req_i.adr[13:3];
wire [63:0] dina = req_i.dat;
wire [63:0] douta;

reg [63:0] dat_o;

// bus interface
reg ack;
wire rd_ack, wr_ack;
wire [31:0] adr3;
wb_asid_t asid3;
wb_tranid_t tid3;
wire [7:0] sel_i = req_i.sel;
reg [63:0] dat_i;
always_comb
begin
	if (req_i.adr[13:0] < 14'h0200) begin
		if (req_i.adr[8])
			dat_i = {req_i.dat[7:0],req_i.dat[15:8],req_i.dat[23:16],req_i.dat[31:24],
				req_i.dat[39:32],req_i.dat[47:40],req_i.dat[55:48],req_i.dat[63:56]};
		else
			dat_i = req_i.dat;
	end
	else
		dat_i = req_i.dat;
end

wire [31:0] adr_i = req_i.adr;

assign cs_config_i = cs_i && req_i.cyc &&
		req_i.adr[27:21]==CFG_BUS &&
		req_i.adr[20:16]==CFG_DEVICE &&
		req_i.adr[15:13]==CFG_FUNC &&
		((BUS_PROTOCOL==0) ? !ack: TRUE);

wire erc = req_i.cti==wishbone_pkg::ERC;
wire cs = cs_config_i;

vtdl #(.WID(1), .DEP(16)) udlyc (.clk(clk_i), .ce(1'b1), .a(0), .d(cs & ~req_i.we), .q(rd_ack));
vtdl #(.WID(1), .DEP(16)) udlyw (.clk(clk_i), .ce(1'b1), .a(0), .d(cs &  req_i.we), .q(wr_ack));
always_comb
	resp_o.ack <= (BUS_PROTOCOL==0) ? ack : (rd_ack|wr_ack);

vtdl #(.WID($bits(wb_tranid_t)), .DEP(16)) udlytid (.clk(clk_i), .ce(1'b1), .a(0), .d(req_i.tid), .q(tid3));
vtdl #(.WID(32), .DEP(16)) udlyadr (.clk(clk_i), .ce(1'b1), .a(0), .d(req_i.adr), .q(adr3));
always_ff @(posedge clk_i)
if (cs) begin
	if (BUS_PROTOCOL==0)
		resp_o.tid <= tid_o;
	else
		resp_o.tid <= tid3;
	if (adr3[13:0] < 14'h0200) begin
		if (adr3[8])
			resp_o.dat <= {dat_o[7:0],dat_o[15:8],dat_o[23:16],dat_o[31:24],
				dat_o[39:32],dat_o[47:40],dat_o[55:48],dat_o[63:56]};
		else
			resp_o.dat <= dat_o;
	end
	else
		resp_o.dat <= dat_o;
	resp_o.err = wishbone_pkg::OKAY;
end
else begin
	resp_o.tid <= 13'd0;
	resp_o.err = wishbone_pkg::OKAY;
	resp_o.dat <= 64'd0;
end
always_comb resp_o.next = 1'd0;
always_comb resp_o.stall = 1'd0;
always_comb resp_o.rty = 1'd0;
always_comb resp_o.pri = 4'd7;

reg [15:0] irq_vect;

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

initial begin
	for (n1 = 0; n1 < 64; n1 = n1 + 1)
		cfg_dat[n1] = 'd0;
end

reg [1:0] state;

always_ff @(posedge clk_i)
if (rst_i) begin
	sleep <= FALSE;
	bar0 <= CFG_BAR0;
	bar1 <= CFG_BAR1;
	bar2 <= CFG_BAR2;
	cmd_reg <= 16'h4003;
	stat_reg <= 16'h0000;
	irq_req <= 4'b0;
	ack <= 1'b0;
	state <= 2'd0;
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

	if (BUS_PROTOCOL==1)
		ack <= 1'b0;

	case(state)
	2'd0:
		if (cs) begin
			if (BUS_PROTOCOL==0) begin
				tid_o <= req_i.tid;
				state <= 2'd1;
			end
			if (req_i.we)
				casez(req_i.adr[13:3])
				11'h001:
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
				11'h002:
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
							if (sel_i[4])	bar1[7:0] <= dat_i[39:32];
							if (sel_i[5])	bar1[15:8] <= dat_i[47:40];
							if (sel_i[6])	bar1[23:16] <= dat_i[55:48];
							if (sel_i[7])	bar1[31:24] <= dat_i[63:56];
						end
					end
				11'h003:
					if (&sel_i[3:0] && dat_i[31:0]==32'hFFFFFFFF)
						bar2 <= CFG_BAR2_MASK;
					else begin
						if (sel_i[0])	bar2[7:0] <= dat_i[7:0];
						if (sel_i[1])	bar2[15:8] <= dat_i[15:8];
						if (sel_i[2])	bar2[23:16] <= dat_i[23:16];
						if (sel_i[3])	bar2[31:24] <= dat_i[31:24];
					end
				// IRQ bus controls
				11'h010:	
					begin
						if (&sel_i[3:0]) irq_vect[0] <= dat_i[15: 0];
						if (&sel_i[7:4]) irq_vect[1] <= dat_i[47:32];
					end
				11'h011:
					begin
						if (&sel_i[3:0]) irq_vect[2] <= dat_i[15: 0];
						if (&sel_i[7:4]) irq_vect[3] <= dat_i[47:32];
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
				casez(req_i.adr[13:3])
				11'h000:
					begin
						dat_o[31: 0] <= {CFG_DEVICE_ID,CFG_VENDOR_ID};
						dat_o[63:32] <= {stato_reg,cmdo_reg};
					end
				11'h001:
					begin
						dat_o[31: 0] <= {CFG_CLASS,CFG_SUBCLASS,CFG_PROGIF,CFG_REVISION_ID};
						dat_o[63:32] <= {8'h00,CFG_HEADER_TYPE,latency_timer,CFG_CACHE_LINE_SIZE};
					end
				11'h002:
					begin
						dat_o[31: 0] <= bar0;
						dat_o[63:32] <= bar1;
					end
				11'h003:
					begin
						dat_o[31: 0] <= bar2;
						dat_o[63:32] <= 32'hFFFFFFFF;
					end
				11'h004:
					begin
						dat_o[31: 0] <= 32'hFFFFFFFF;
						dat_o[63:32] <= 32'hFFFFFFFF;
					end
				11'h005:
					begin
						dat_o[31: 0] <= 32'h0;
						dat_o[63:32] <= {CFG_SUBSYSTEM_ID,CFG_SUBSYSTEM_VENDOR_ID};
					end
				11'h006:
					begin
						dat_o[31: 0] <= CFG_ROM_ADDR;
						dat_o[63:32] <= 32'h0;
					end
				11'h008:
					begin
						dat_o[31: 0] <= irq_vect[0];
						dat_o[63:32] <= irq_vect[1];
					end
				11'h009:
					begin
						dat_o[31: 0] <= irq_vect[2];
						dat_o[63:32] <= irq_vect[3];
					end
				12'h010:	dat_o <= pDevName[63: 0];
				12'h011:	dat_o <= {pDevName[127:64]};
				default:	dat_o <= douta;
				endcase
		end
	2'd1:
		begin
			ack <= 1'b1;
			state <= 2'd2;
		end
	2'd2:
		if (!req_i.cyc) begin
			ack <= 1'b0;
			tid_o <= 16'd0;
			dat_o <= 64'd0;
			state <= 2'd0;
		end
	default:	state <= 2'd0;
	endcase
end

// Trigger IRQ message if IRQ signal set.
wire irq_empty = irq_chain_i==16'd0;

always_ff @(posedge clk_i)
if (rst_i) begin
	irqf <= 4'h0;
	irq_i2 <= 4'h0;
	irq_chain_o <= 16'd0;
end
else begin
	irq_chain_o <= irq_chain_i;
	for (n2 = 0; n2 < NIRQ; n2 = n2 + 1) begin
		irq_i2[n2] <= irq_i[n2];
		if (irq_i[n2]|irq_req[n2])
			irqf[n2] <= irq_timer[n2]==6'h3F;
	end
	for (n2 = NIRQ-1; n2 >= 0; n2 = n2 - 1) begin
		if (irqf[n2] && irq_empty) begin
			irqf[n2] <= FALSE;
			irq_chain_o <= irq_vect[n2];
		end
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

//always_comb
//	irq_o = {irq_device,2'd0,irq_core,1'b0,irq_channel,irq_priority,cause_code};
//	irq_o = {31'd0,irq_i & ~int_disable} << irq_line;

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
else
	assign douta = 64'd0;
end
endgenerate

endmodule
