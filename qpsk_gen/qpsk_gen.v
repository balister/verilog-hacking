`default_nettype none

// Attach 7 segment display PMOD to Icebreaker PMOD1A port.

module top(
           input  CLK,
           output P1A1,
           output P1A2,
           output P1A3,
           output P1A4,
           output P1A7,
           output P1A8,
           output P1A9,
           output P1A10
           );

   // Wiring external pins.
   reg [6:0]      seg_pins_n;
   reg            digit_sel;
   assign {P1A9, P1A8, P1A7, P1A4, P1A3, P1A2, P1A1} = seg_pins_n;
   assign P1A10 = digit_sel;

   // counter increments at CLK = 12 MHz.
   // ones digit increments at ~6Hz.
   // display refreshes at 375 KHz.
   reg [29:0]     counter;
//   wire [3:0]     ones = counter[21+:4];
//   wire [3:0]     tens = counter[25+:4];

   wire [3:0] ones = i_out[15:12];
   wire [3:0] tens = q_out[15:12];

   always @(posedge CLK) begin
      counter <= counter + 1;
   end

   wire clk = counter[4];

   wire [15:0] i_in = 16'd32767;
   wire [15:0] q_in = 0;

   wire [15:0] i_out;
   wire [15:0] q_out;

   wire [31:0] phase;
   wire [15:0] phase_out;

   wire reset = 0;
   wire enable = 1;
   wire [31:0] freq = 200;

   cordic cordic1(clk, reset, enable, i_in, q_in, i_out, q_out, phase[31:16], phase_out);

   phase_acc nco(clk, reset, freq, phase);

   display_driver display_count(CLK, ones, tens, seg_pins_n, digit_sel);

endmodule // top

module cordic(
	input clk,
	input reset,
	input enable,
	input [15:0] xi, yi,
	output [15:0] xo, yo,
	input [15:0] zi,
	output [15:0] zo);

    reg [17:0] x0, y0;
    reg [14:0] z0;
    wire [17:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12;
    wire [17:0] y1, y2, y3, y4, y5, y6, y7, y8, y9, y10, y11, y12;
    wire [14:0] z1, z2, z3, z4, z5, z6, z7, z8, z9, z10, z11, z12;

    wire [17:0] xi_ext = {{2{xi[15]}}, xi};
    wire [17:0] yi_ext = {{2{yi[15]}}, yi};

    `define c00 16'd8192
    `define c01 16'd4836
    `define c02 16'd2555
    `define c03 16'd1297
    `define c04 16'd651
    `define c05 16'd326
    `define c06 16'd163
    `define c07 16'd81
    `define c08 16'd41
    `define c09 16'd20
    `define c10 16'd10
    `define c11 16'd5
    `define c12 16'd3
    `define c13 16'd1
    `define c14 16'd1
    `define c15 16'd0
    `define c16 16'd0

    always @(posedge clk)
	    if (reset) begin
		    x0 <= #1 0; y0 <= #1 0; z0 <= #1 0;
            end
            else if (enable) begin
		    z0 <= #1 zi[14:0];
		    case (zi[15:14])
			    2'b00, 2'b11 :
			    begin
				    x0 <= #1 xi_ext;
				    y0 <= #1 yi_ext;
			    end
			    2'b01, 2'b10 :
			    begin
				    x0 <= #1 -xi_ext;
				    y0 <= #1 -yi_ext;
			    end
		    endcase
	    end

	    cordic_stage #(18,15,0) cordic_stage0(clk, reset, enable, x0, y0, z0, `c00, x1, y1, z1);
	    cordic_stage #(18,15,1) cordic_stage1(clk, reset, enable, x1, y1, z1, `c01, x2, y2, z2);
	    cordic_stage #(18,15,2) cordic_stage2(clk, reset, enable, x2, y2, z2, `c02, x3, y3, z3);
	    cordic_stage #(18,15,3) cordic_stage3(clk, reset, enable, x3, y3, z3, `c03, x4, y4, z4);
	    cordic_stage #(18,15,4) cordic_stage4(clk, reset, enable, x4, y4, z4, `c04, x5, y5, z5);
	    cordic_stage #(18,15,5) cordic_stage5(clk, reset, enable, x5, y5, z5, `c05, x6, y6, z6);
	    cordic_stage #(18,15,6) cordic_stage6(clk, reset, enable, x6, y6, z6, `c06, x7, y7, z7);
	    cordic_stage #(18,15,7) cordic_stage7(clk, reset, enable, x7, y7, z7, `c07, x8, y8, z8);
	    cordic_stage #(18,15,8) cordic_stage8(clk, reset, enable, x8, y8, z8, `c08, x9, y9, z9);
	    cordic_stage #(18,15,9) cordic_stage9(clk, reset, enable, x9, y9, z9, `c09, x10, y10, z10);
	    cordic_stage #(18,15,10) cordic_stage10(clk, reset, enable, x10, y10, z10, `c10, x11, y11, z11);
	    cordic_stage #(18,15,11) cordic_stage11(clk, reset, enable, x11, y11, z11, `c11, x12, y12, z12);

	    assign xo = x12[16:1];
	    assign yo = y12[16:1];
	    assign zo = z12;

endmodule // cordic

module cordic_stage (
	input clk,
	input reset,
	input enable,
	input [bitwidth-1:0] xi, yi,
	input [zwidth-1:0] zi,
	input [zwidth-1:0] constant,
	output [bitwidth-1:0] xo, yo,
	output [zwidth-1:0] zo );

	parameter bitwidth = 16;
	parameter zwidth = 16;
	parameter shift = 1;

	wire z_is_pos = ~zi[zwidth-1];

	reg [bitwidth-1:0] xo, yo;
	reg [zwidth-1:0] zo;

	always@(posedge clk)
		if (reset) begin
			xo <= #1 0;
			yo <= #1 0;
			zo <= #1 0;
		end
		else if (enable) begin
			xo <= #1 z_is_pos ?
				xi - {{shift+1{yi[bitwidth-1]}},yi[bitwidth-2:shift]} :
				xi + {{shift+1{yi[bitwidth-1]}},yi[bitwidth-2:shift]};
			yo <= #1 z_is_pos ?
				yi - {{shift+1{xi[bitwidth-1]}},xi[bitwidth-2:shift]} :
				yi + {{shift+1{xi[bitwidth-1]}},xi[bitwidth-2:shift]};
			zo <= #1 z_is_pos ?
				zi - constant :
				zi + constant;
		end

endmodule // cordic_stage

module phase_acc(
	input clk,
	input reset,
	input [31:0] freq,
	output reg [31:0] phase );

   always @(posedge clk)
	   if (reset)
		   phase <= 32'b0;
	   else
		   phase <= phase + freq;

endmodule // phase_acc

module display_driver(
	input clk,
	input [3:0] ones,
	input [3:0] tens,
	output [6:0] segments,
	output digit_select );

   reg [2:0]     display_state;
   reg [6:0]     ones_segments;
   reg [6:0]     tens_segments;

   digit_to_segments ones2segs(clk, ones, ones_segments);
   digit_to_segments tens2segs(clk, tens, tens_segments);

   always @(posedge clk) begin
      display_state <= display_state + 1;

      // Switch segments off during digit_select transitions
      // to prevent flicker.  Each digit has 25% duty cycle.
      case (display_state)
        0, 1: segments <= ~ones_segments;
        2:    segments <= ~0;
        3:    digit_select <= 0;
        4, 5: segments <= ~tens_segments;
        6:    segments <= ~0;
        7:    digit_select <= 1;
      endcase
   end
endmodule // display_driver



// Get the segments to illuminate to display a single hex digit.
// N.B., This is positive logic.  Display needs negative.
module digit_to_segments(input clk,
                         input [3:0] digit,
                         output reg[6:0] segments
                         );
   always @(posedge clk)
     case (digit)
       0: segments <= 7'b0111111;
       1: segments <= 7'b0000110;
       2: segments <= 7'b1011011;
       3: segments <= 7'b1001111;
       4: segments <= 7'b1100110;
       5: segments <= 7'b1101101;
       6: segments <= 7'b1111101;
       7: segments <= 7'b0000111;
       8: segments <= 7'b1111111;
       9: segments <= 7'b1101111;
       4'hA: segments <= 7'b1110111;
       4'hB: segments <= 7'b1111100;
       4'hC: segments <= 7'b0111001;
       4'hD: segments <= 7'b1011110;
       4'hE: segments <= 7'b1111001;
       4'hF: segments <= 7'b1110001;
     endcase

endmodule // digit_to_segments
