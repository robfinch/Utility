// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
// 442 LUTs / 240 FFs
// ============================================================================
//
import const_pkg::*;

module ddbb256_config(rst_i, clk_i, irq_i, irq_o, cs_config_i, 
	tid_i, cyc_i, tid_o, ack_o, we_i, sel_i, adr_i, dat_i, dat_o, ready_i,
	cs_bar0_o, cs_bar1_o, cs_bar2_o, irq_en_o);
input rst_i;
input clk_i;
input irq_i;
output reg [31:0] irq_o;
input cs_config_i;
input [15:0] tid_i;
input cyc_i;
output reg [15:0] tid_o;
output reg ack_o;
input we_i;
input [31:0] sel_i;
input [31:0] adr_i;
input [255:0] dat_i;
output reg [255:0] dat_o;
input ready_i;
output reg irq_en_o;
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
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter BUS_PROTOCOL = 0;		// 0=WISHBONE, 1=FTA
parameter MSIX = 1'b0;

integer n1;
reg [2:0] state;
wire cs;
reg ack;
reg [15:0] tid;
reg [255:0] dat;
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

always_comb
	if (BUS_PROTOCOL==1) begin
		if (ready_i) begin
			ack_o = ack;
			dat_o = dat;
			tid_o = tid;
		end
		else begin
			ack_o = FALSE;
			dat_o = 256'd0;
			tid_o = 16'd0;
		end
	end
	else begin
		ack_o = ack & cs;
		dat_o = dat;
		tid_o = tid;
	end

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

reg [255:0] cfg_dat [0:15];
reg [7:0] irq_line;

initial begin
	for (n1 = 0; n1 < 32; n1 = n1 + 1)
		cfg_dat[n1] = 'd0;
end

assign cs = cs_config_i &&
	cyc_i &&
	adr_i[27:21]==CFG_BUS &&
	adr_i[20:16]==CFG_DEVICE &&
	adr_i[15:13]==CFG_FUNC &&
	(BUS_PROTOCOL==1 ? !ack : TRUE);

always_ff @(posedge clk_i)
if (rst_i) begin
	bar0 <= CFG_BAR0;
	bar1 <= CFG_BAR1;
	bar2 <= CFG_BAR2;
	cmd_reg <= 16'h4003;
	stat_reg <= 16'h0000;
	irq_line <= CFG_IRQ_LINE;
	state <= 3'd0;
	ack <= FALSE;
	dat <= 256'd0;
	tid <= 16'd0;
	int_disable <= 1'b1;
	irq_en_o <= 1'b0;
end
else begin
	io_space <= cmdo_reg[0];
	memory_space <= cmdo_reg[1];
	bus_master <= cmdo_reg[2];
	parity_err_resp <= cmdo_reg[6];
	serr_enable <= cmdo_reg[8];
	int_disable <= cmdo_reg[10];
	irq_en_o <= ~cmdo_reg[10];

	// FTA bus: ack only one cycle	
	if (BUS_PROTOCOL==1) begin
		ack <= FALSE;
		dat <= 256'd0;
		tid <= 16'd0;
	end

	case(state)
	3'd0:
		if (cs) begin
			tid <= tid_i;
			if (BUS_PROTOCOL==0)
				state <= 3'd1;
			if (we_i)
				case(adr_i[8:5])
				4'h0:
					begin
						if (sel_i[8]) cmd_reg[7:0] <= dat_i[71:64];
						if (sel_i[9]) cmd_reg[15:8] <= dat_i[79:72];
						if (sel_i[11]) begin
							if (dat_i[8]) stat_reg[8] <= 1'b0;
							if (dat_i[11]) stat_reg[11] <= 1'b0;
							if (dat_i[12]) stat_reg[12] <= 1'b0;
							if (dat_i[13]) stat_reg[13] <= 1'b0;
							if (dat_i[14]) stat_reg[14] <= 1'b0;
							if (dat_i[15]) stat_reg[15] <= 1'b0;
						end
						if (&sel_i[19:16] && dat_i[159:128]==32'hFFFFFFFF)
							bar0 <= CFG_BAR0_MASK;
						else begin
							if (sel_i[16])	bar0[7:0] <= dat_i[135:128];
							if (sel_i[17])	bar0[15:8] <= dat_i[143:136];
							if (sel_i[18])	bar0[23:16] <= dat_i[151:144];
							if (sel_i[19])	bar0[31:24] <= dat_i[159:152];
						end
						if (&sel_i[23:20] && dat_i[191:160]==32'hFFFFFFFF)
							bar1 <= CFG_BAR1_MASK;
						else begin
							if (sel_i[20])	bar1[7:0] <= dat_i[167:160];
							if (sel_i[21])	bar1[15:8] <= dat_i[175:168];
							if (sel_i[22])	bar1[23:16] <= dat_i[183:176];
							if (sel_i[23])	bar1[31:24] <= dat_i[191:184];
						end
						if (&sel_i[27:24] && dat_i[223:192]==32'hFFFFFFFF)
							bar2 <= CFG_BAR2_MASK;
						else begin
							if (sel_i[24])	bar2[7:0] <= dat_i[199:192];
							if (sel_i[25])	bar2[15:8] <= dat_i[207:200];
							if (sel_i[26])	bar2[23:16] <= dat_i[215:208];
							if (sel_i[27])	bar2[31:24] <= dat_i[223:216];
						end
					end
				4'h1:
					if (sel_i[12]) irq_line <= dat_i[103:96];
				default:
					begin
						if (sel_i[0]) cfg_dat[adr_i[8:5]][7:0] <= dat_i[7:0];
						if (sel_i[1]) cfg_dat[adr_i[8:5]][15:8] <= dat_i[15:8];
						if (sel_i[2]) cfg_dat[adr_i[8:5]][23:16] <= dat_i[23:16];
						if (sel_i[3]) cfg_dat[adr_i[8:5]][31:24] <= dat_i[31:24];
						if (sel_i[4]) cfg_dat[adr_i[8:5]][39:32] <= dat_i[39:32];
						if (sel_i[5]) cfg_dat[adr_i[8:5]][47:40] <= dat_i[47:40];
						if (sel_i[6]) cfg_dat[adr_i[8:5]][55:48] <= dat_i[55:48];
						if (sel_i[7]) cfg_dat[adr_i[8:5]][63:56] <= dat_i[63:56];
						if (sel_i[8]) cfg_dat[adr_i[8:5]][71:64] <= dat_i[71:64];
						if (sel_i[9]) cfg_dat[adr_i[8:5]][79:72] <= dat_i[79:72];
						if (sel_i[10]) cfg_dat[adr_i[8:5]][87:80] <= dat_i[87:80];
						if (sel_i[11]) cfg_dat[adr_i[8:5]][95:88] <= dat_i[95:88];
						if (sel_i[12]) cfg_dat[adr_i[8:5]][103:96] <= dat_i[103:96];
						if (sel_i[13]) cfg_dat[adr_i[8:5]][111:104] <= dat_i[111:104];
						if (sel_i[14]) cfg_dat[adr_i[8:5]][119:112] <= dat_i[119:112];
						if (sel_i[15]) cfg_dat[adr_i[8:5]][127:120] <= dat_i[127:120];
						if (sel_i[16]) cfg_dat[adr_i[8:5]][135:128] <= dat_i[135:128];
						if (sel_i[17]) cfg_dat[adr_i[8:5]][143:136] <= dat_i[143:136];
						if (sel_i[18]) cfg_dat[adr_i[8:5]][151:144] <= dat_i[151:144];
						if (sel_i[19]) cfg_dat[adr_i[8:5]][159:152] <= dat_i[159:152];
						if (sel_i[20]) cfg_dat[adr_i[8:5]][167:160] <= dat_i[167:160];
						if (sel_i[21]) cfg_dat[adr_i[8:5]][175:168] <= dat_i[175:168];
						if (sel_i[22]) cfg_dat[adr_i[8:5]][183:176] <= dat_i[183:176];
						if (sel_i[23]) cfg_dat[adr_i[8:5]][191:184] <= dat_i[191:184];
						if (sel_i[24]) cfg_dat[adr_i[8:5]][199:192] <= dat_i[199:192];
						if (sel_i[25]) cfg_dat[adr_i[8:5]][207:200] <= dat_i[207:200];
						if (sel_i[26]) cfg_dat[adr_i[8:5]][215:208] <= dat_i[215:208];
						if (sel_i[27]) cfg_dat[adr_i[8:5]][223:216] <= dat_i[223:216];
						if (sel_i[28]) cfg_dat[adr_i[8:5]][231:224] <= dat_i[231:224];
						if (sel_i[29]) cfg_dat[adr_i[8:5]][239:232] <= dat_i[239:232];
						if (sel_i[30]) cfg_dat[adr_i[8:5]][247:240] <= dat_i[247:240];
						if (sel_i[31]) cfg_dat[adr_i[8:5]][255:248] <= dat_i[255:248];
					end
				endcase
			else begin
				if (BUS_PROTOCOL==1)
					ack <= TRUE;
				case(adr_i[8:5])
				4'h00:	dat <= {32'hFFFFFFFF,bar2,bar1,bar0,8'h00,
					CFG_HEADER_TYPE,latency_timer,CFG_CACHE_LINE_SIZE,
					stato_reg,cmdo_reg,CFG_DEVICE_ID,CFG_VENDOR_ID};
				4'h01:	dat <= {8'd8,8'd0,8'd0,irq_line,32'd0,32'd0,CFG_ROM_ADDR,CFG_SUBSYSTEM_ID,CFG_SUBSYSTEM_VENDOR_ID,32'h0,64'hFFFFFFFFFFFFFFFF};
				default:	dat <= cfg_dat[adr_i[8:5]];
				endcase
			end
		end
	3'd1:
		begin
			ack <= TRUE;
			state <= 3'd2;
		end
	3'd2:
		if (!cs) begin
			ack <= FALSE;
			tid <= 16'd0;
			dat <= 256'd0;
			state <= 3'd0;
		end
	default:
		state <= 3'd0;
	endcase
end

always_comb
	irq_o = {31'd0,irq_i & ~int_disable} << irq_line;

always_comb
	cs_bar0_o = ((adr_i ^ bar0) & CFG_BAR0_MASK) == 'd0;
always_comb
	cs_bar1_o = ((adr_i ^ bar1) & CFG_BAR1_MASK) == 'd0;
always_comb
	cs_bar2_o = ((adr_i ^ bar2) & CFG_BAR2_MASK) == 'd0;
	
endmodule
