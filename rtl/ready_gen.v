// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2019  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@opencores.org
//       ||
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                            
// ready_gen.v
// - generates a ready signal after a specified number of clocks.
// - this is not a simple delay line. Output is set low as soom as the
//   input goes low.
//
// ============================================================================
//
module ready_gen(clk_i, ce_i, i, o, id_i, id_o);
parameter STAGES = 3;
parameter WID=6;
input clk_i;
input ce_i;
input i;
output reg o = 1'd0;
input [WID-1:0] id_i;
output reg [WID-1:0] id_o;

integer n;
reg [STAGES-1:0] rdy;
reg [WID-1:0] id [0:STAGES-1];
always @(posedge clk_i)
if (ce_i) begin
	rdy[0] <= i;
	id[0] <= id_i;
	for (n = 1; n < STAGES; n = n + 1) begin
		rdy[n] <= rdy[n-1] & i;
		id[n] <= id[n-1] & {4{i}};
	end
	o <= rdy[STAGES-1] & i;
	id_o <= id[STAGES-1] & {4{i}};
end

endmodule
