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
   wire [3:0]     ones = counter[21+:4];
   wire [3:0]     tens = counter[25+:4];

   always @(posedge CLK) begin
      counter <= counter + 1;
   end

   display_driver display_count(CLK, ones, tens, seg_pins_n, digit_sel);

endmodule // top

module display_driver(
	input clk,
	input [4:0] ones,
	input [4:0] tens,
	input [6:0] segments,
	input digit_select );

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
