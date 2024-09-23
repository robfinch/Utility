// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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

module ddbb128_config(rst_i, clk_i, irq_i, irq_o, cs_config_i, 
	we_i, sel_i, adr_i, dat_i, dat_o,
	cs_bar0_o, cs_bar1_o, cs_bar2_o, irq_en_o);
input rst_i;
input clk_i;
input irq_i;
output reg [31:0] irq_o;
input cs_config_i;
input we_i;
input [15:0] sel_i;
input [31:0] adr_i;
input [127:0] dat_i;
output reg [127:0] dat_o;
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

parameter MSIX = 1'b0;

integer n1;
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

reg [127:0] cfg_dat [0:31];
reg [7:0] irq_line;

initial begin
	for (n1 = 0; n1 < 32; n1 = n1 + 1)
		cfg_dat[n1] = 'd0;
end

wire cs = cs_config_i &&
	adr_i[27:20]==CFG_BUS &&
	adr_i[19:15]==CFG_DEVICE &&
	adr_i[14:12]==CFG_FUNC;

always_ff @(posedge clk_i)
if (rst_i) begin
	bar0 <= CFG_BAR0;
	bar1 <= CFG_BAR1;
	bar2 <= CFG_BAR2;
	cmd_reg <= 16'h4003;
	stat_reg <= 16'h0000;
	irq_line <= CFG_IRQ_LINE;
end
else begin
	io_space <= cmdo_reg[0];
	memory_space <= cmdo_reg[1];
	bus_master <= cmdo_reg[2];
	parity_err_resp <= cmdo_reg[6];
	serr_enable <= cmdo_reg[8];
	int_disable <= cmdo_reg[10];
	irq_en_o <= ~cmdo_reg[10];

	if (cs) begin
		if (we_i)
			case(adr_i[8:4])
			5'h00:
				begin
					if (sel_i[8]) cmd_reg[7:0] <= dat_i[7:0];
					if (sel_i[9]) cmd_reg[15:8] <= dat_i[15:8];
					if (sel_i[11]) begin
						if (dat_i[8]) stat_reg[8] <= 1'b0;
						if (dat_i[11]) stat_reg[11] <= 1'b0;
						if (dat_i[12]) stat_reg[12] <= 1'b0;
						if (dat_i[13]) stat_reg[13] <= 1'b0;
						if (dat_i[14]) stat_reg[14] <= 1'b0;
						if (dat_i[15]) stat_reg[15] <= 1'b0;
					end
				end
			5'h01:
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
					if (&sel_i[11:8] && dat_i[95:64]==32'hFFFFFFFF)
						bar2 <= CFG_BAR2_MASK;
					else begin
						if (sel_i[8])	bar2[7:0] <= dat_i[71:64];
						if (sel_i[9])	bar2[15:8] <= dat_i[79:72];
						if (sel_i[10])	bar2[23:16] <= dat_i[87:80];
						if (sel_i[11])	bar2[31:24] <= dat_i[95:88];
					end
				end
			5'h03:
				if (sel_i[12]) irq_line <= dat_i[103:96];
			default:
				begin
					if (sel_i[0]) cfg_dat[adr_i[8:4]][7:0] <= dat_i[7:0];
					if (sel_i[1]) cfg_dat[adr_i[8:4]][15:8] <= dat_i[15:8];
					if (sel_i[2]) cfg_dat[adr_i[8:4]][23:16] <= dat_i[23:16];
					if (sel_i[3]) cfg_dat[adr_i[8:4]][31:24] <= dat_i[31:24];
					if (sel_i[4]) cfg_dat[adr_i[8:4]][39:32] <= dat_i[39:32];
					if (sel_i[5]) cfg_dat[adr_i[8:4]][47:40] <= dat_i[47:40];
					if (sel_i[6]) cfg_dat[adr_i[8:4]][55:48] <= dat_i[55:48];
					if (sel_i[7]) cfg_dat[adr_i[8:4]][63:56] <= dat_i[63:56];
					if (sel_i[8]) cfg_dat[adr_i[8:4]][71:64] <= dat_i[71:64];
					if (sel_i[9]) cfg_dat[adr_i[8:4]][79:72] <= dat_i[79:72];
					if (sel_i[10]) cfg_dat[adr_i[8:4]][87:80] <= dat_i[87:80];
					if (sel_i[11]) cfg_dat[adr_i[8:4]][95:88] <= dat_i[95:88];
					if (sel_i[12]) cfg_dat[adr_i[8:4]][103:96] <= dat_i[103:96];
					if (sel_i[13]) cfg_dat[adr_i[8:4]][111:104] <= dat_i[111:104];
					if (sel_i[14]) cfg_dat[adr_i[8:4]][119:112] <= dat_i[119:112];
					if (sel_i[15]) cfg_dat[adr_i[8:4]][127:120] <= dat_i[127:120];
				end
			endcase
		else
			case(adr_i[8:4])
			5'h00:	dat_o <= {8'h00,
				CFG_HEADER_TYPE,latency_timer,CFG_CACHE_LINE_SIZE,
				stato_reg,cmdo_reg,CFG_DEVICE_ID,CFG_VENDOR_ID};
			5'h01:	dat_o <= {32'hFFFFFFFF,bar2,bar1,bar0};
			5'h02:	dat_o <= {CFG_SUBSYSTEM_ID,CFG_SUBSYSTEM_VENDOR_ID,32'h0,64'hFFFFFFFFFFFFFFFF};
			5'h03:	dat_o <= {8'd8,8'd0,8'd0,irq_line,32'd0,32'd0,CFG_ROM_ADDR};
			default:	dat_o <= cfg_dat[adr_i[8:4]];
			endcase
	end
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
