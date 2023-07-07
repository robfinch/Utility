
import fta_bus_pkg::*;

module ledport_fta64(rst, clk, cs, req, resp, led);
input rst;
input clk;
input cs;
input fta_cmd_request64_t req;
output fta_cmd_response64_t resp;
output reg [7:0] led;

always_ff @(posedge clk, posedge rst)
if (rst)
	led <= 'd0;
else begin
	if (cs & req.we)
		led <= req.dat[7:0];
end

always_ff @(posedge clk, posedge rst)
if (rst)
	resp <= 'd0;
else begin
	resp.cid <= req.cid;
	resp.tid <= req.tid;		
	resp.ack <= cs && (!req.we || req.cti==fta_bus_pkg::ERC);
	resp.err <= 'd0;
	resp.rty <= 'd0;
	resp.pri <= 4'd7;
	resp.adr <= req.padr;
	resp.dat <= 'd0;
end

endmodule
