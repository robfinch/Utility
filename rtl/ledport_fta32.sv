
import fta_bus_pkg::*;

module ledport_fta32(rst, clk, cs, req, resp, led);
input rst;
input clk;
input cs;
input fta_cmd_request32_t req;
output fta_cmd_response32_t resp;
output reg [7:0] led;

always_ff @(posedge clk, posedge rst)
if (rst)
	led <= 'd0;
else begin
	if (cs & req.we)
		led <= req.dat[7:0];
end

assign resp.tid = req.tid;
assign resp.ack = cs && (!req.we || req.cti==fta_bus_pkg::ERC);
assign resp.err = fta_bus_pkg::OKAY;
assign resp.rty = 'd0;
assign resp.pri = 4'd7;
assign resp.adr = req.padr;
assign resp.dat = 'd0;

endmodule
