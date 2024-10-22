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
// 192 LUTs / 144 FFs / 1 BRAM
// ============================================================================
//
import const_pkg::*;
import fta_bus_pkg::*;

module ddbb32B_config(rst_i, clk_i, irq_i, cs_config_i, req_i, resp_o,
	cs_bar0_o, cs_bar1_o, cs_bar2_o);
input rst_i;
input clk_i;
input [7:0] irq_i;
input cs_config_i;
input fta_cmd_request256_t req_i;
output fta_cmd_response256_t resp_o;
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

parameter CFG_ROM_FILENAME = "ddbb_config.mem";

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;

integer n1;
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

// RAM / ROM signals
wire rsta = rst_i;
wire clka = clk_i;
wire [31:0] wea = {32{req_i.we & cs_config_i}} && req_i.sel && req_i.padr[11:9]==3'd0;
wire ena = 1'b1;
wire [6:0] addra = req_i.padr[11:5];
wire [255:0] dina = req_i.data1;
wire [255:0] douta;

reg [255:0] dat_o;

// FTA bus interface
wire rd_ack, wr_ack;
wire [31:0] adr3;
fta_asid_t asid3;
fta_tranid_t tid3;
wire [31:0] sel_i = req_i.sel;
wire [255:0] dat_i = req_i.data1;
wire [31:0] adr_i = req_i.padr;

assign resp_o.dat = dat_o;
wire erc = req_i.cti==ERC;

vtdl #(.WID(1), .DEP(16)) udlyc (.clk(clk_i), .ce(1'b1), .a(2), .d(cs_config_i & ~req_i.we), .q(rd_ack));
vtdl #(.WID(1), .DEP(16)) udlyw (.clk(clk_i), .ce(1'b1), .a(2), .d(cs_config_i &  req_i.we & erc), .q(wr_ack));
always_ff @(posedge clk_i)
	resp_o.ack <= (rd_ack|wr_ack);

vtdl #(.WID($bits(fta_asid_t)), .DEP(16)) udlyasid (.clk(clk_i), .ce(1'b1), .a(2), .d(req_i.asid), .q(asid3));
vtdl #(.WID($bits(fta_tranid_t)), .DEP(16)) udlytid (.clk(clk_i), .ce(1'b1), .a(2), .d(req_i.tid), .q(tid3));
vtdl #(.WID(32), .DEP(16)) udlyadr (.clk(clk_i), .ce(1'b1), .a(2), .d(req_i.padr), .q(adr3));
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
	logic [4:0] resv;
	logic [2:0] pri;
	logic [7:0] cause;
	// target
	logic [2:0] resvt;
	fta_tranid_t tid;
	// source
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

wire cs = cs_config_i &&
	req_i.padr[27:20]==CFG_BUS &&
	req_i.padr[19:15]==CFG_DEVICE &&
	req_i.padr[14:12]==CFG_FUNC;

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

	if (cs & req_i.cyc) begin
		if (req_i.we)
			case(req_i.padr[11:5])
			7'h0:
				begin
					if (sel_i[8]) cmd_reg[7:0] <= dat_i[39:32];
					if (sel_i[9]) cmd_reg[15:8] <= dat_i[47:40];
					if (sel_i[11]) begin
						if (dat_i[40]) stat_reg[8] <= 1'b0;
						if (dat_i[43]) stat_reg[11] <= 1'b0;
						if (dat_i[44]) stat_reg[12] <= 1'b0;
						if (dat_i[45]) stat_reg[13] <= 1'b0;
						if (dat_i[46]) stat_reg[14] <= 1'b0;
						if (dat_i[47]) stat_reg[15] <= 1'b0;
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
			// IRQ bus controls
			7'h02:
				begin
					if (&sel_i[7:0]) irq_info[3'd0] <= dat_i[63:0];
					if (&sel_i[15:8]) irq_info[3'd1] <= dat_i[127:64];
					if (&sel_i[23:16]) irq_info[3'd2] <= dat_i[191:128];
					if (&sel_i[31:24]) irq_info[3'd3] <= dat_i[255:192];
				end
			7'h03:
				begin
					if (&sel_i[7:0]) irq_info[3'd4] <= dat_i[63:0];
					if (&sel_i[15:8]) irq_info[3'd5] <= dat_i[127:64];
					if (&sel_i[23:16]) irq_info[3'd6] <= dat_i[191:128];
					if (&sel_i[31:24]) irq_info[3'd7] <= dat_i[255:192];
				end
			default:
				;
			endcase
		else
			case(adr_i[11:5])
			7'h00:
				begin
					dat_o[31:0] <= {CFG_DEVICE_ID,CFG_VENDOR_ID};
					dat_o[63:32] <= {stato_reg,cmdo_reg};
					dat_o[95:64] <= {CFG_CLASS,CFG_SUBCLASS,CFG_PROGIF,CFG_REVISION_ID};
					dat_o[127:96] <= {8'h00,CFG_HEADER_TYPE,latency_timer,CFG_CACHE_LINE_SIZE};
					dat_o[159:128] <= bar0;
					dat_o[191:160] <= bar1;
					dat_o[223:192] <= bar2;
					dat_o[255:224] <= 32'hFFFFFFFF;
				end
			7'h01:
				begin
					dat_o[31:0] <= 32'hFFFFFFFF;
					dat_o[63:32] <= 32'hFFFFFFFF;
					dat_o[95:64] <= 32'h0;
					dat_o[127:96] <= {CFG_SUBSYSTEM_ID,CFG_SUBSYSTEM_VENDOR_ID};
					dat_o[159:128] <= CFG_ROM_ADDR;
					dat_o[191:160] <= 32'h0;
					dat_o[255:192] <= 64'd0;
				end
			7'h02:
				begin
					dat_o[63:0] <= irq_info[3'd0];
					dat_o[127:64] <= irq_info[3'd1];
					dat_o[191:128] <= irq_info[3'd2];
					dat_o[255:192] <= irq_info[3'd3];
				end
			7'h03:
				begin
					dat_o[63:0] <= irq_info[3'd4];
					dat_o[127:64] <= irq_info[3'd5];
					dat_o[191:128] <= irq_info[3'd6];
					dat_o[255:192] <= irq_info[3'd7];
				end
			default:	dat_o <= douta;
			endcase
	end
end

//always_comb
//	irq_o = {irq_device,2'd0,irq_core,1'b0,irq_channel,irq_priority,cause_code};
//	irq_o = {31'd0,irq_i & ~int_disable} << irq_line;

always_comb
	cs_bar0_o = ((req_i.padr ^ bar0) & CFG_BAR0_MASK) == 'd0;
always_comb
	cs_bar1_o = ((req_i.padr ^ bar1) & CFG_BAR1_MASK) == 'd0;
always_comb
	cs_bar2_o = ((req_i.padr ^ bar2) & CFG_BAR2_MASK) == 'd0;


// XPM_MEMORY instantiation template for Single Port RAM configurations
// Refer to the targeted device family architecture libraries guide for XPM_MEMORY documentation
// =======================================================================================================================

   // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_spram #(
      .ADDR_WIDTH_A(7),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       	// DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE(CFG_ROM_FILENAME),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(8*4096),          // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(256),       // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(256),      // DECIMAL
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

endmodule
