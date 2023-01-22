/* ===============================================================
	(C) 2006-2021  Robert Finch
	All rights reserved.
	rob@birdcomputer.ca

	delay.v
		- delays signals by so many clock cycles


	This source code is free for use and modification for
	non-commercial or evaluation purposes, provided this
	copyright statement and disclaimer remains present in
	the file.

	If you do modify the code, please state the origin and
	note that you have modified the code.

	NO WARRANTY.
	THIS Work, IS PROVIDEDED "AS IS" WITH NO WARRANTIES OF
	ANY KIND, WHETHER EXPRESS OR IMPLIED. The user must assume
	the entire risk of using the Work.

	IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
	ANY INCIDENTAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES
	WHATSOEVER RELATING TO THE USE OF THIS WORK, OR YOUR
	RELATIONSHIP WITH THE AUTHOR.

	IN ADDITION, IN NO EVENT DOES THE AUTHOR AUTHORIZE YOU
	TO USE THE WORK IN APPLICATIONS OR SYSTEMS WHERE THE
	WORK'S FAILURE TO PERFORM CAN REASONABLY BE EXPECTED
	TO RESULT IN A SIGNIFICANT PHYSICAL INJURY, OR IN LOSS
	OF LIFE. ANY SUCH USE BY YOU IS ENTIRELY AT YOUR OWN RISK,
	AND YOU AGREE TO HOLD THE AUTHOR AND CONTRIBUTORS HARMLESS
	FROM ANY CLAIMS OR LOSSES RELATING TO SUCH UNAUTHORIZED
	USE.

=============================================================== */

module delay1
	#(parameter WID = 1)
	(
	input clk,
	input ce,
	input [WID:1] i,
	output reg [WID:1] o
	);

	always @(posedge clk)
		if (ce)
			o <= i;

endmodule


module delay2
	#(parameter WID = 1)
	(
	input clk,
	input ce,
	input [WID:1] i,
	output reg [WID:1] o
	);


	reg	[WID:1]	r1;
	
	always @(posedge clk)
		if (ce)
			r1 <= i;
	
	always @(posedge clk)
		if (ce)
			o <= r1;
	
endmodule


module delay3
	#(parameter WID = 1)
	(
	input clk,
	input ce,
	input [WID:1] i,
	output reg [WID:1] o
	);

	reg	[WID:1] r1, r2;
	
	always @(posedge clk)
		if (ce)
			r1 <= i;
	
	always @(posedge clk)
		if (ce)
			r2 <= r1;
	
	always @(posedge clk)
		if (ce)
			o <= r2;
			
endmodule
	
module delay4
	#(parameter WID = 1)
	(
	input clk,
	input ce,
	input [WID-1:0] i,
	output reg [WID-1:0] o
	);

	reg	[WID-1:0] r1, r2, r3;
	
	always @(posedge clk)
		if (ce)
			r1 <= i;
	
	always @(posedge clk)
		if (ce)
			r2 <= r1;
	
	always @(posedge clk)
		if (ce)
			r3 <= r2;
	
	always @(posedge clk)
		if (ce)
			o <= r3;

endmodule

	
module delay5
#(parameter WID = 1)
(
	input clk,
	input ce,
	input [WID:1] i,
	output reg [WID:1] o
);

	reg	[WID:1] r1, r2, r3, r4;
	
	always @(posedge clk)
		if (ce) r1 <= i;
	
	always @(posedge clk)
		if (ce) r2 <= r1;
	
	always @(posedge clk)
		if (ce) r3 <= r2;
	
	always @(posedge clk)
		if (ce) r4 <= r3;
	
	always @(posedge clk)
		if (ce) o <= r4;
	
endmodule

module delay6
#(parameter WID = 1)
(
	input clk,
	input ce,
	input [WID:1] i,
	output reg [WID:1] o
);

	reg	[WID:1] r1, r2, r3, r4, r5;
	
	always @(posedge clk)
		if (ce) r1 <= i;
	
	always @(posedge clk)
		if (ce) r2 <= r1;
	
	always @(posedge clk)
		if (ce) r3 <= r2;
	
	always @(posedge clk)
		if (ce) r4 <= r3;
	
	always @(posedge clk)
		if (ce) r5 <= r4;
	
	always @(posedge clk)
		if (ce) o <= r5;
	
endmodule

module ft_delay(clk, ce, i, o);
parameter WID = 1;
parameter DEP = 1;
input clk;
input ce;
input [WID-1:0] i;
output reg [WID-1:0] o;

reg [WID-1:0] pldreg [0:DEP-1];

integer n;
initial begin
	for (n = 0; n < DEP; n = n + 1)
		pldreg[n] = 'd0;
end

/*
reg [WID-1:0] pldreg [0:15];

always_ff @(posedge clk) if (ce) pldreg[0] <= i;
always_ff @(posedge clk) if (ce) pldreg[1] <= pldreg[0];
always_ff @(posedge clk) if (ce) pldreg[2] <= pldreg[1];
always_ff @(posedge clk) if (ce) pldreg[3] <= pldreg[2];
always_ff @(posedge clk) if (ce) pldreg[4] <= pldreg[3];
always_ff @(posedge clk) if (ce) pldreg[5] <= pldreg[4];
always_ff @(posedge clk) if (ce) pldreg[6] <= pldreg[5];
always_ff @(posedge clk) if (ce) pldreg[7] <= pldreg[6];
always_ff @(posedge clk) if (ce) pldreg[8] <= pldreg[7];
always_ff @(posedge clk) if (ce) pldreg[9] <= pldreg[8];
always_ff @(posedge clk) if (ce) pldreg[10] <= pldreg[9];
always_ff @(posedge clk) if (ce) pldreg[11] <= pldreg[10];
always_ff @(posedge clk) if (ce) pldreg[12] <= pldreg[11];
always_ff @(posedge clk) if (ce) pldreg[13] <= pldreg[12];
always_ff @(posedge clk) if (ce) pldreg[14] <= pldreg[13];
always_ff @(posedge clk) if (ce) pldreg[15] <= pldreg[14];

always_comb
	case(DEP)
	4'd0:	o = i;
	4'd1:	o = pldreg[0];
	4'd2:	o = pldreg[1];
	4'd3:	o = pldreg[2];
	4'd4:	o = pldreg[3];
	4'd5:	o = pldreg[4];
	4'd6:	o = pldreg[5];
	4'd7:	o = pldreg[6];
	4'd8:	o = pldreg[7];
	4'd9:	o = pldreg[8];
	4'd10:	o = pldreg[9];
	4'd11:	o = pldreg[10];
	4'd12:	o = pldreg[11];
	4'd13:	o = pldreg[12];
	4'd14:	o = pldreg[13];
	4'd15:	o = pldreg[14];
	endcase
*/
/*
genvar g;
generate begin : gPipeline
  for (g = 0; g < WID; g = g + 1)
c_shift_ram_0 u1 (
  .A(DEP),    // input wire [3 : 0] A
  .D(i[g]),      // input wire [0 : 0] D
  .CLK(clk),  // input wire CLK
  .CE(ce),    // input wire CE
  .Q(o[g])      // output wire [0 : 0] Q
);
end
endgenerate
*/

genvar g;
generate begin : gPipeline
	always_ff @(posedge clk)
		if (ce)
			pldreg[0] <= i;
  for (g = 0; g < DEP - 1; g = g + 1)
    always_ff @(posedge clk)
    	if (ce) begin
     		pldreg[g+1] <= pldreg[g];
    	end
  assign o = pldreg[DEP-1];    
end
endgenerate

endmodule
