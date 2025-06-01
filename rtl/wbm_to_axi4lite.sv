
module wbm_to_axi4lite(rst_i, clk_i, 
	wbm_cyc, wbm_stb, wbm_ack, wbm_err, wbm_we, wbm_sel, wbm_adr, wbm_dat_i, wbm_dat_o,
	aclk, arstn,
	araddr, arcache, arprot, arvalid, arready, rdata, rresp, rvalid, rready,
	awaddr, awcache, awprot, awvalid, awready, wdata, wstb, bresp, bvalid, bready
);
parameter DBW = 32;
input rst_i;
input clk_i;
input wbm_cyc;
input wbm_stb;
input wbm_we;
output reg wbm_ack;
output reg wbm_err;
input [DBW/8-1:0] wbm_sel;
input [31:0] wbm_adr;
output [DBW-1:0] wbm_dat_i;
input [DBW-1:0] wbm_dat_o;

output [31:0] araddr;
output [3:0] arcache;
output [2:0] arprot;
output arvalid;
input arready;
input [DBW-1:0] rdata;
input [1:0] rresp;
input rvalid;
output rready;

output [31:0] awaddr;
output [3:0] awcache;
output [2:0] awprot;
output awvalid;
input awready;
output [DBW-1:0] wdata;
output [DBW/8-1:0] wstb;
input [1:0] bresp;
input bvalid;
output bready;

assign arstn = ~rst_i;
assign aclk = clk_i;

assign araddr = wbm_adr;
assign arcache = 4'b0011;
assign arprot = 3'b000;			// Normal, secure, data
assign arvalid = arready ? wbm_cyc & wbm_stb & ~wbm_we : 1'b0;
assign rready = wbm_cyc & wbm_stb & ~wbm_we;

assign awaddr = wbm_adr;
assign wcache = 4'b0011;		// Normal, non-cacheable, modifiable, bufferable
assign awprot = 3'b000;			// Normal, secure, data
assign awvalid = awready ? wbm_cyc & wbm_stb & wbm_we : 1'b0;
assign wdata = wbm_dat_o;
assign wstb = awready ? wbm_sel : {DBW/8{1'b0}};
assign bready = 1'b1;				// the master ignores write responses, so it is always ready

assign wbm_dat_i = rdata;

always_comb
begin
	wbm_ack_o = 1'b0;
	wbm_err_o = 1'b0;
	if (wbm_cyc && wbm_stb && !wbm_we && rvalid && rready && rresp==2'b00)
		wbm_ack_o = 1'b1;
	if (wbm_cyc && wbm_stb && !wbm_we && rvalid && rready && rresp!=2'b00)
		wbm_err_o = 1'b1;
	if (wbm_cyc && wbm_stb && wbm_we && bvalid && bresp == 2'b00)
		wbm_ack_o = 1'b1;
	if (wbm_cyc && wbm_stb && wbm_we && bvalid && bresp != 2'b00)
		wbm_err_o = 1'b1;
end

endmodule
