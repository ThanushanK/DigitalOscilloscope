// Background image display

	////////////////// TO PASS array onto other modules ////////////
	//output [sampleBitWidth * screenWidth-1:0] pointVector; //ADDED
	//reg [sampleBitWidth-1:0] point [0:screenWidth-1]; //CHANGED from output reg to reg	
	//genvar i;
	//generate for (i = 0; i < screenWidth; i = i+1) begin: pointM
   //assign pointVector[screenWidth*i +: screenWidth] = point[i];
	//end endgenerate																
	///////////////////////////////////////////////////////////////

module background
	(
		ySign,							// 0(+) 1(-)
		iY,								//	y value from shift registers
		clk,						//	On Board 50 MHz
		KEY,								//	Push Button[1:0]
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK,						//	VGA BLANK
		VGA_SYNC,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,							//	VGA Blue[9:0]
		oX									//	x position on the screen
	);
	
	input		ySign;					// 0(+) 1(-)
	input		[32:0] iY;				//	y value from shift registers
	input		clk;				//	50 MHz
	input		[1:0] KEY;				//	Button[1:0]
	output	VGA_CLK;   				//	VGA Clock
	output	VGA_HS;					//	VGA H_SYNC
	output	VGA_VS;					//	VGA V_SYNC
	output	VGA_BLANK;				//	VGA BLANK
	output	VGA_SYNC;				//	VGA SYNC
	output	[9:0] VGA_R;   		//	VGA Red[9:0]
	output	[9:0] VGA_G;	 		//	VGA Green[9:0]
	output	[9:0] VGA_B;   		//	VGA Blue[9:0]
	output	[7:0] oX;				//	x position on the screen

	
	wire resetn, plot;
	wire [2:0] color;
	wire [7:0] x;
	wire [6:0] y;
   //wire [31:0] dataIn [0:159]; //Data read from the input waveform 

 	assign resetn = KEY[0];
	//assign oX = x;

	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(clk),
			.colour(color),
			.x(x),
			.y(y),
			.plot(plot),
			/* Signals for the DAC to drive the monitor. */
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
		
		DO_Controller FSM (clk, ~KEY[1], color, x, y, iY, ySign, plot, oX);//, LEDG[1:0], LEDR[7:0], LEDR[17:11], SW[7:0]);
		
endmodule

module DO_Controller (clock, isPaused, oColour, oX, oY, iY, ySign, plot, iX);//, led, ledX, ledY, ySwitch);
input clock, isPaused, ySign;
input [32:0] iY;
input [7:0] iX;
//input [31:0] dataPlot [0:159];
output reg [2:0] oColour;
output reg [7:0] oX;
output reg [6:0] oY;
output reg plot;

parameter idle = 2'b00, clearDisplay = 2'b01, displayGraph = 2'b10, pauseGraph = 3'b11; //States
parameter maxWidth = 160, maxHeight = 120;

reg isCleared = 1'b0; //determines whether the graph is cleared and only the background is left
reg isGraphed = 1'b0; //determines whether one instance of the waveform has been plotted
reg[2:0] curState, nextState;
reg [6:0] prevTempY;

wire [2:0] colorOfPixel;
reg [7:0] tempX = 0;
reg [6:0] tempY = 0;


/////TEST//////////
//input [6:0] ySwitch;
//output [1:0] led;
//output [7:0] ledX;
//output [6:0] ledY;
//assign ledX = oX;
//assign ledY = oY;
//assign led = curState;
///////////////////

////////////////////////////////State Switcher/////////////////////////////////

always @ (*)
begin
	case (curState)
		idle: nextState <= clearDisplay;
		
		clearDisplay: if (isCleared == 'b1) nextState <= displayGraph;
						  else nextState <= clearDisplay;
			
		displayGraph: begin
						  if (isPaused == 'b1 && isGraphed == 'b1) nextState <= pauseGraph;
						  else if (isGraphed == 'b1) nextState <= idle;
						  else nextState <= displayGraph;
						  end
						  
		pauseGraph: if (isPaused == 'b0) nextState <= idle;
						else nextState <= pauseGraph;	
						
	   default: nextState <= idle;
	endcase
end

always @(posedge clock) 
begin
	curState <= nextState;
end
///////////////////////////////////////////////////////////////////////////////

imageGet clear(colorOfPixel, tempX + (maxWidth * tempY), clock);


always @ (posedge clock)
begin	
		oX = tempX;
		oY = tempY;
		
	if (curState == idle) //Resets flags
	begin
		tempY = 7'b00000000;
		isCleared <= 'b0;	
	   isGraphed <= 'b0;	
		plot <= 'b1;	
	end 
	
	if (curState == clearDisplay) //Redraws the background image over the current display
	begin			
	   oColour = colorOfPixel; //color of current coordinate pixels COLOR from the background image
	
		if (tempY != maxHeight)
			begin
				if (tempX == maxWidth)
				begin
					tempY = tempY + 1;
				end
				else	
					tempX = tempX + 1;
			end
		else
			begin
				isCleared <= 'b1;     
		      tempY = 7'b0000000;  
			end			
	end
	
	else if (curState == displayGraph) //Draws graph
	begin
		oColour = 'b100; //RED
		tempX <= iX;
		
		if (ySign == 0)
			tempY <= 60-iY;
		else
			tempY <= 60+iY;

			if (tempX != maxWidth-1)
				isGraphed <= 'b0;				
			else
				isGraphed <= 'b1; 
		
	end
	
	else if (curState == pauseGraph)//Pauses full graph so user can see the waveform
	begin
	plot <= 'b0;	
	end
end
endmodule


//Get The Color from the specific address of the Background Image
module imageGet (dataOut, address, clk);
parameter width = 3;
parameter page = 16;

input clk;
input [page - 1: 0] address;
output [width - 1 : 0] dataOut;

BackgroundImage	BackgroundImage_inst (
	.address ( address ),
	.clock ( clk ),
	.q ( dataOut )
	);
	
endmodule
