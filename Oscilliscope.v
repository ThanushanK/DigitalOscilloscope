module Oscilliscope(

// SDRAM COMPONENTS //
inout		[15:0]DRAM_DQ,					//	SDRAM Data bus 16 Bits
output	[11:0]DRAM_ADDR,				//	SDRAM Address bus 12 Bits
output			DRAM_LDQM,				//	SDRAM Low-byte Data Mask 
output			DRAM_UDQM,				//	SDRAM High-byte Data Mask
output			DRAM_WE_N,				//	SDRAM Write Enable
output			DRAM_CAS_N,				//	SDRAM Column Address Strobe
output			DRAM_RAS_N,				//	SDRAM Row Address Strobe
output			DRAM_CS_N,				//	SDRAM Chip Select
output			DRAM_BA_0,				//	SDRAM Bank Address 0
output			DRAM_BA_1,				//	SDRAM Bank Address 0
output			DRAM_CLK,				//	SDRAM Clock
output			DRAM_CKE,				//	SDRAM Clock Enable

// AUDIO CODEC COMPONENTS //
inout			AUD_ADCLRCK,				//	Audio CODEC ADC LR Clock
input			AUD_ADCDAT,					//	Audio CODEC ADC Data
inout			AUD_DACLRCK,				//	Audio CODEC DAC LR Clock
output		AUD_DACDAT,					//	Audio CODEC DAC Data
inout			AUD_BCLK,					//	Audio CODEC Bit-Stream Clock
output		AUD_XCK,						//	Audio CODEC Chip Clock

inout			I2C_SDAT,					//	I2C Data
output		I2C_SCLK,					//	I2C Clock

// VGA //
output			VGA_CLK,   				//	VGA Clock
output			VGA_HS,					//	VGA H_SYNC
output			VGA_VS,					//	VGA V_SYNC
output			VGA_BLANK,				//	VGA BLANK
output			VGA_SYNC,				//	VGA SYNC
output	[9:0]	VGA_R,   				//	VGA Red[9:0]
output	[9:0]	VGA_G,	 				//	VGA Green[9:0]
output	[9:0]	VGA_B,  					//	VGA Blue[9:0]

input			CLOCK_50,					//	On Board 50 MHz

input	[1:0]	KEY,							//	Pushbutton[3:0]
input	[17:0] SW,							//	Toggle Switch[17:0]
output [6:0] HEX4,					 	// Hex voltD_1
output [6:0] HEX5,					 	// Hex voltD_10
output [6:0] HEX6,						// Hex timeD_1
output [6:0] HEX7,						// Hex timeD_10
output [8:8] LEDG							// blinking led
);

// SDRAM //
wire reset = !KEY[0];

wire [21:0] ram_addr;
wire [15:0] ram_data_in, ram_data_out;
wire ram_valid, ram_waitrq, ram_read, ram_write;

// Audio //
wire				audio_in_available;
wire		[31:0]	left_channel_audio_in;
wire		[31:0]	right_channel_audio_in;
wire				read_audio_in;
wire				audio_out_allowed;
wire		[31:0]	left_channel_audio_out;
wire		[31:0]	right_channel_audio_out;
wire				write_audio_out;

// VGA //
wire ySign;
wire [31:0] iY;
wire [2:0] vga_color;
wire [8:0] vga_x;
wire [7:0] vga_y;
wire vga_plot;

// Blinkenlights //
assign LEDG[8] = KEY[1] ? blink_cnt[25] : 0;

reg [25:0] blink_cnt;
always @(posedge CLOCK_50) 
begin
blink_cnt <= blink_cnt + 1;
end

///////////////////////////
// MODULE INSTANTIATIONS //
///////////////////////////

// HEX //
HEX_Display voltD_1 (SW[2:0], HEX4);
HEX_Display voltD_10 (0, HEX5);
HEX_Display timeD_1 (SW[5:3], HEX6);
HEX_Display timeD_10 (0, HEX7);

SDRAM_PLL pll(.inclk0(CLOCK_50), .c0(DRAM_CLK), .c1(VGA_CLK), .c2(AUD_XCK));
			
Audio_Controller Audio_Controller (
	// Inputs
	.clk						(CLOCK_50),
	.reset						(reset),

	.clear_audio_in_memory		(),
	.read_audio_in				(read_audio_in),
	
	.clear_audio_out_memory		(),
	.left_channel_audio_out		(left_channel_audio_out),
	.right_channel_audio_out	(right_channel_audio_out),
	.write_audio_out			(write_audio_out),

	.AUD_ADCDAT					(AUD_ADCDAT),

	// Bidirectionals
	.AUD_BCLK					(AUD_BCLK),
	.AUD_ADCLRCK				(AUD_ADCLRCK),
	.AUD_DACLRCK				(AUD_DACLRCK),
	.I2C_SDAT				   (I2C_SDAT),


	// Outputs
	.audio_in_available			(audio_in_available),
	.left_channel_audio_in		(left_channel_audio_in),
	.right_channel_audio_in		(right_channel_audio_in),

	.audio_out_allowed			(audio_out_allowed),

	.AUD_XCK					(),
	.AUD_DACDAT					(AUD_DACDAT),
	.I2C_SCLK(I2C_SCLK)

);

Audio sound (KEY[1:0], audio_in_available, left_channel_audio_in,  right_channel_audio_in, audio_out_allowed,  SW[17:0], read_audio_in, left_channel_audio_out, right_channel_audio_out, write_audio_out, ySign, iY, vga_x);
									
defparam
	Audio_Controller.USE_MIC_INPUT = 0; // 0 - for line in or 1 - for microphone in

vga_adapter VGA(
			.resetn(!reset),
			.clock(CLOCK_50),
			.colour(vga_color),
			.x(vga_x),
			.y(vga_y),
			.plot(vga_plot),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK),
			.VGA_SYNC(VGA_SYNC),
			.clock_25(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "display.mif";

VGA_Display disp(CLOCK_50, ySign, iY, vga_x, vga_y, vga_color, vga_plot, KEY[1:0]);

endmodule
