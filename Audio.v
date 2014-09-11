module Audio (
	//AUDIO COMPONENTS
	// Inputs	
	KEY,
	audio_in_available,
	left_channel_audio_in, 
	right_channel_audio_in,
	audio_out_allowed,
	
	// Outputs
	SW,
	read_audio_in,
	left_channel_audio_out,
	right_channel_audio_out,
	write_audio_out,
	
	//VIDEO COMPONENTS 
	oySign,							// 0(+) 1(-)
	oY,								//	y value from shift registers
	iX
);

//AUDIO COMPONENTS
// Inputs
input		[1:0]	KEY;
input		[17:0]SW;

//VIDEO COMPONENTS
output   		oySign;					// 0(+) 1(-)
output [31:0] 	oY;				//	y value from shift registers
input  [7:0] 	iX;				//	x position on the screen

// Internal Wireswire				
input			audio_in_available;
input	[31:0]left_channel_audio_in;
input	[31:0]right_channel_audio_in;
output		read_audio_in;

input			audio_out_allowed;
output[31:0]left_channel_audio_out;
output[31:0]right_channel_audio_out;
output		write_audio_out;

assign read_audio_in				= audio_in_available & audio_out_allowed;
assign left_channel_audio_out	= left_channel_audio_in;
assign right_channel_audio_out= right_channel_audio_in; 
assign write_audio_out			= audio_in_available & audio_out_allowed;

wire	[31:0] channel_audio_in = SW[17] ? right_channel_audio_in: left_channel_audio_in;

Shift_Registers SR (channel_audio_in, audio_in_available, SW[5:3], SW[2:0], KEY[0], iX, oY, oySign); 

endmodule

//Stores a full graph and updates it once input is available
module Shift_Registers (audioIn, audioAvailable, timeDIV, voltDIV, reset, x, y, ySign);
	input reset, audioAvailable;
	input signed [sampleBitWidth-1:0] audioIn;
	input [2:0] timeDIV;
	input [2:0] voltDIV;
	input [7:0] x;
	
	output reg [31:0] y;	
	output reg ySign = 0;

	parameter sampleBitWidth = 32;
	parameter screenWidth = 160;
	
	wire signed [31:0] scaledAudio;
	
	reg signed [sampleBitWidth-1:0] point [0:screenWidth-1];
	reg [15:0] count;
	
	always @ (*)
	begin 
		y = $unsigned (point [x]);
		if (scaledAudio[31] == 1)
			ySign = 1;
		else 
			ySign = 0;
	end	
	
	Integer_Scaling u1 (audioIn, scaledAudio, voltDIV);
	
	integer a, i;
	
	always @ (negedge reset, posedge audioAvailable)
		if (~reset)
			begin
			for (a = 0; a< screenWidth; a = a + 1)
			begin
				point [a] <= 'sd0;
			end
			count<=0; 	
			end
		else
			begin
			if(count >= timeDIV)//skips input information to compress graph
				begin
				for (i = 0; i<screenWidth-1; i = i + 1)//shift
					begin
					point [i]<=point[i+1];
					end
				point[screenWidth-1]<= scaledAudio;						
				count<=0;
				end
			else
				count <= count + 1; 		
			end
endmodule

//Scales the 32 bit input from a to +/- 0-60 (also multiplies by timeDiv)
module Integer_Scaling(in, out, scalingFactor);
	parameter inWidth = 32;//cant change paramater because ((2**(inWidth-1))-1) doesnt work
	parameter outWidth = 32;
	parameter outMax = 'sd60;
	
	input [3:0] scalingFactor;//for voltDIV
	input signed [inWidth-1:0]in;
	output signed [outWidth-1:0]out;
	
	wire signed [4:0] signedScalingFactor;
	wire signed [41:0] product;
	
	assign signedScalingFactor = $signed (scalingFactor);
	assign product = (in*outMax*signedScalingFactor)/32'sd2147483647;//32'sd2147483647 = ((2**(inWidth-1))-1)
		
	assign out = product;//(in*outMax*scalingFactor)/((2**(inWidth-1))-1);
	
endmodule

