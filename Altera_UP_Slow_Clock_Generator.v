/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_Slow_Clock_Generator                              *
 * Description:                                                              *
 *      This module can create clock signals that have a frequency lower     *
 *   than those a PLL can generate.                                          *
 *                                                                           *
 * Revision: 1.1                                                             *
 *                                                                           *
 * Used in IP Cores:                                                         *
 *   Altera UP Avalon Audio and Video Config                                 *
 *                                                                           *
 *****************************************************************************/

module Altera_UP_Slow_Clock_Generator (
	// Inputs
	clk,
	reset,
	
	enable_clk,

	// Bidirectionals

	// Outputs
	new_clk,

	rising_edge,
	falling_edge,

	middle_of_high_level,
	middle_of_low_level
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/

parameter COUNTER_BITS	= 10;
parameter COUNTER_INC	= 10'h001;

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

// Inputs
input				clk;
input				reset;

input				enable_clk;
	
// Bidirectionals

// Outputs
output	reg			new_clk;

output	reg			rising_edge;
output	reg			falling_edge;

output	reg			middle_of_high_level;
output	reg			middle_of_low_level;

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/

// Internal Wires

// Internal Registers
reg			[COUNTER_BITS:1]	clk_counter;

// State Machine Registers

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/


/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		clk_counter	<= {COUNTER_BITS{1'b0}};
	else if (enable_clk == 1'b1)
		clk_counter	<= clk_counter + COUNTER_INC;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		new_clk	<= 1'b0;
	else
		new_clk	<= clk_counter[COUNTER_BITS];
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		rising_edge	<= 1'b0;
	else
		rising_edge	<= (clk_counter[COUNTER_BITS] ^ new_clk) & ~new_clk;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		falling_edge <= 1'b0;
	else
		falling_edge <= (clk_counter[COUNTER_BITS] ^ new_clk) & new_clk;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		middle_of_high_level <= 1'b0;
	else
		middle_of_high_level <= 
			clk_counter[COUNTER_BITS] & 
			~clk_counter[(COUNTER_BITS - 1)] &
			(&(clk_counter[(COUNTER_BITS - 2):1]));
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		middle_of_low_level <= 1'b0;
	else
		middle_of_low_level <= 
			~clk_counter[COUNTER_BITS] & 
			~clk_counter[(COUNTER_BITS - 1)] &
			(&(clk_counter[(COUNTER_BITS - 2):1]));
end



/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

// Output Assignments

// Internal Assignments

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

endmodule

