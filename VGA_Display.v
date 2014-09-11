module VGA_Display
	(		
		clk,								// on board 50Mhz clock
		ySign,							// 0(+) 1(-)
		iY,								//	y value from shift registers				
		oX,								// current x coordinate
		oY,								// current y coordinate
		oColor,							// colour corresponding to coordinate	
		oPlot,							//	1 = plot to screen
		KEY								
	);
	
	input				ySign;			// 0(+) 1(-)
	input		[32:0]iY;				//	y value from shift registers
	input				clk;				//	50 MHz
	input		[1:0] KEY;				//	Button[1:0]
	
	output   [8:0] oX;				// current x coordinate
	output   [7:0] oY;				// current y coordinate
	output   [2:0]	oColor;			// colour corresponding to coordinate	
	output 			oPlot;			//	1 = plot to screen
		
	DO_Controller FSM (clk, ~KEY[1], oColor, oX, oY, iY, ySign, oPlot);

endmodule

module DO_Controller (clock, isPaused, oColour, oX, oY, iY, ySign, plot);

input clock, isPaused, ySign;
input [32:0] iY;

output reg [2:0] oColour;
output reg [7:0] oX;
output reg [6:0] oY;
output reg plot;

parameter idle = 2'b00, clearDisplay = 2'b01, displayGraph = 2'b10, pauseGraph = 2'b11; //States
parameter maxWidth = 160, maxHeight = 120;

reg isCleared = 1'b0; //determines whether the graph is cleared and only the background is left
reg isGraphed = 1'b0; //determines whether one instance of the waveform has been plotted
reg[2:0] curState, nextState;
reg [7:0] tempX = 0;
reg [6:0] tempY;

wire [2:0] colorOfPixel;


// State Switcher //
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
		tempY = 7'b0000000;
		tempX = 8'b00000000;
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
					tempX = 8'b00000000;
				end
				else	
					tempX = tempX + 1;
			end
		else
			begin
				isCleared <= 'b1;  
				tempX = 8'b00000000;
		      tempY = 7'b0000000;  
			end			
	end
	
	else if (curState == displayGraph) //Draws graph
	begin
		oColour = 'b100; //RED
		
	    if (ySign == 0)
			tempY = 60-iY;
		else
			tempY = 60+iY;

			if (tempX != maxWidth-1)
			begin
				tempX <= tempX + 1;
				isGraphed <= 'b0;		
			end
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
parameter page = 18;

input 						clk;
input [page - 1: 0]	 	address;
output [width - 1 : 0] 	dataOut;

backgroundImage	backgroundImage_inst (
	.address ( address ),
	.clock ( clk ),
	.q ( dataOut )
	);

	
endmodule
