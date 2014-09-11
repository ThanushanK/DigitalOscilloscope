/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_Avalon_Audio_and_Video_Config                     *
 * Description:                                                              *
 *      This module sends and receives data from the audio's and TV in's     *
 *   control registers for the chips on Altera's DE2 board. Plus, it can     *
 *   send and receive data from the TRDB_DC2 and TRDB_LCM add-on modules.    *
 *                                                                           *
 *****************************************************************************/

module Audio_and_Video_Config (
	// Inputs
	clk,
	reset,

	ob_address,
	ob_byteenable,
	ob_chipselect,
	ob_read,
	ob_write,
	ob_writedata,

	// Bidirectionals
	I2C_SDAT,

	// Outputs
	ob_readdata,
	ob_waitrequest,
	
	I2C_SCLK
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/

parameter USE_MIC_INPUT			= 0;

localparam I2C_BUS_MODE			= 1'b0;

localparam MIN_ROM_ADDRESS		= 6'h00;
localparam MAX_ROM_ADDRESS		= 6'h0A;

localparam AUD_LINE_IN_LC		= 9'd24;
localparam AUD_LINE_IN_RC		= 9'd24;
localparam AUD_LINE_OUT_LC		= 9'd119;
localparam AUD_LINE_OUT_RC		= 9'd119;
localparam AUD_ADC_PATH			= 9'd17;
localparam AUD_DAC_PATH			= 9'd6;
localparam AUD_POWER				= 9'h000;
localparam AUD_DATA_FORMAT		= 9'd77;
localparam AUD_SAMPLE_CTRL		= 9'd0;
localparam AUD_SET_ACTIVE		= 9'h001;

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				clk;
input				reset;

input		[2:0]	ob_address;
input		[3:0]	ob_byteenable;
input				ob_chipselect;
input				ob_read;
input				ob_write;
input		[31:0]	ob_writedata;

// Bidirectionals
inout				I2C_SDAT;					//	I2C Data

// Outputs
output		[31:0]	ob_readdata;
output				ob_waitrequest;

output				I2C_SCLK;					//	I2C Clock

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
localparam	I2C_STATE_0_IDLE			= 2'h0,
			I2C_STATE_1_START			= 2'h1,
			I2C_STATE_2_TRANSFERING		= 2'h2,
			I2C_STATE_3_COMPLETE		= 2'h3;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires
wire				internal_reset;

wire				valid_operation;

wire				clk_400KHz;
wire				start_and_stop_en;
wire				change_output_bit_en;

wire				enable_clk;

wire		[1:0]	address;
wire		[3:0]	byteenable;
wire				chipselect;
wire				read;
wire				write;
wire		[31:0]	writedata;

wire		[31:0]	readdata;
wire				waitrequest;

wire				clear_status_bits;

wire				send_start_bit;
wire				send_stop_bit;

wire		[7:0]	auto_init_data;
wire				auto_init_transfer_data;
wire				auto_init_start_bit;
wire				auto_init_stop_bit;
wire				auto_init_complete;
wire				auto_init_error;

wire				transfer_data;
wire				transfer_complete;

wire				i2c_ack;
wire		[7:0]	i2c_received_data;

// Internal Registers
reg			[7:0]	data_to_transfer;
reg			[2:0]	num_bits_to_transfer;

reg					read_byte;
reg					transfer_is_read;

// State Machine Registers
reg			[1:0]	ns_alavon_slave;
reg			[1:0]	s_alavon_slave;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge clk)
begin
	if (internal_reset == 1'b1)
	begin
		s_alavon_slave <= I2C_STATE_0_IDLE;
	end
	else
	begin
		s_alavon_slave <= ns_alavon_slave;
	end
end

always @(*)
begin
	// Defaults
	ns_alavon_slave = I2C_STATE_0_IDLE;

    case (s_alavon_slave)
	I2C_STATE_0_IDLE:
		begin
			if ((valid_operation == 1'b1) && (auto_init_complete == 1'b1))
			begin
				ns_alavon_slave = I2C_STATE_1_START;
			end
			else
			begin
				ns_alavon_slave = I2C_STATE_0_IDLE;
			end
		end
	I2C_STATE_1_START:
		begin
			ns_alavon_slave = I2C_STATE_2_TRANSFERING;
		end
	I2C_STATE_2_TRANSFERING:
		begin
			if (transfer_complete == 1'b1)
			begin
				ns_alavon_slave = I2C_STATE_3_COMPLETE;
			end
			else
			begin
				ns_alavon_slave = I2C_STATE_2_TRANSFERING;
			end
		end
	I2C_STATE_3_COMPLETE:
		begin
			ns_alavon_slave = I2C_STATE_0_IDLE;
		end
	default:
		begin
			ns_alavon_slave = I2C_STATE_0_IDLE;
		end
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

always @(posedge clk)
begin
	if (internal_reset == 1'b1)
	begin
		data_to_transfer		<= 8'h00;
		num_bits_to_transfer	<= 3'h0;
	end
	else if (auto_init_complete == 1'b0)
	begin
		data_to_transfer		<= auto_init_data;
		num_bits_to_transfer	<= 3'h7;
	end
	else if (s_alavon_slave == I2C_STATE_1_START)
	begin
		num_bits_to_transfer <= 3'h7;
		if ((ob_address == 3'h0) & writedata[2])
			data_to_transfer <= 8'h34;
		else if ((ob_address == 3'h4) & writedata[2])
			data_to_transfer <= 8'h40 | writedata[3];
		else
			data_to_transfer <= writedata[7:0];
	end
end

always @(posedge clk)
	if (reset == 1'b1)
		read_byte <= 1'b0;
	else if (s_alavon_slave == I2C_STATE_1_START)
		read_byte <= read;

always @(posedge clk)
	if (reset == 1'b1)
		transfer_is_read <= 1'b0;
	else if ((s_alavon_slave == I2C_STATE_1_START) && (address == 2'h0))
		transfer_is_read <= writedata[3];

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

// Output Assignments
assign ob_readdata		= readdata;
assign ob_waitrequest	= waitrequest;

// Internal Assignments
assign readdata[31: 8]	= 24'h000000;
assign readdata[ 7: 4]	= (address == 2'h3) ? i2c_received_data[7:4]	: 4'h0;
assign readdata[ 3]		= (address == 2'h1) ? auto_init_error			: 
						  (address == 2'h3) ? i2c_received_data[3]		: 1'b0;
assign readdata[ 2]		= (address == 2'h1) ? ~auto_init_complete		: 
						  (address == 2'h3) ? i2c_received_data[2]		: 1'b0;
assign readdata[ 1]		= (address == 2'h1) ? 
							(s_alavon_slave != I2C_STATE_0_IDLE)		: 
						  (address == 2'h3) ? i2c_received_data[1]		: 1'b0;
assign readdata[ 0]		= (address == 2'h1) ? i2c_ack					: 
						  (address == 2'h3) ? i2c_received_data[0]		: 1'b0;

assign waitrequest = valid_operation & 
			((write & (s_alavon_slave != I2C_STATE_1_START)) |
			(read & ~transfer_complete));

assign address		= ob_address[1:0];
assign byteenable	= ob_byteenable;
assign chipselect	= ob_chipselect;
assign read			= ob_read;
assign write		= ob_write;
assign writedata	= ob_writedata;

assign internal_reset		= 
			reset | 
			(chipselect & byteenable[0] & (address == 2'h0) & 
				write & writedata[0]);

assign valid_operation		= 
			chipselect & byteenable[0] & (
				((address == 2'h0) & write & ~writedata[0]) |
				((address == 2'h2) & write) |
				 (address == 2'h3)
				);

assign clear_status_bits	= chipselect & (address == 2'h1) & write;

assign transfer_data		= 
			auto_init_transfer_data | 
			(s_alavon_slave == I2C_STATE_2_TRANSFERING);

assign send_start_bit		= 
			auto_init_start_bit | 
			(chipselect & byteenable[0] & (address == 2'h0) & 
				write & writedata[2]);

assign send_stop_bit = 
			auto_init_stop_bit |
			(chipselect & byteenable[0] & (address == 2'h0) & 
				write & writedata[1]);

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

Altera_UP_Slow_Clock_Generator Clock_Generator_400KHz (
	// Inputs
	.clk					(clk),
	.reset					(internal_reset),

	.enable_clk				(enable_clk),
	
	// Bidirectionals

	// Outputs
	.new_clk				(clk_400KHz),

	.rising_edge			(),
	.falling_edge			(),

	.middle_of_high_level	(start_and_stop_en),
	.middle_of_low_level	(change_output_bit_en)
);
defparam
	Clock_Generator_400KHz.COUNTER_BITS	= 10, // 4, // 
	Clock_Generator_400KHz.COUNTER_INC	= 10'h001; // 4'h1; // 

Altera_UP_I2C_AV_Auto_Initialize Auto_Initialize (
	// Inputs
	.clk				(clk),
	.reset				(internal_reset),

	.clear_error		(clear_status_bits),

	.ack				(i2c_ack),
	.transfer_complete	(transfer_complete),

	// Bidirectionals

	// Outputs
	.data_out			(auto_init_data),
	.transfer_data		(auto_init_transfer_data),
	.send_start_bit		(auto_init_start_bit),
	.send_stop_bit		(auto_init_stop_bit),

	.auto_init_complete	(auto_init_complete),
	.auto_init_error	(auto_init_error)
);
defparam
	Auto_Initialize.MIN_ROM_ADDRESS	= MIN_ROM_ADDRESS,
	Auto_Initialize.MAX_ROM_ADDRESS	= MAX_ROM_ADDRESS,

	Auto_Initialize.USE_MIC_INPUT = USE_MIC_INPUT,

	Auto_Initialize.AUD_LINE_IN_LC	= AUD_LINE_IN_LC,
	Auto_Initialize.AUD_LINE_IN_RC	= AUD_LINE_IN_RC,
	Auto_Initialize.AUD_LINE_OUT_LC	= AUD_LINE_OUT_LC,
	Auto_Initialize.AUD_LINE_OUT_RC	= AUD_LINE_OUT_RC,
	Auto_Initialize.AUD_ADC_PATH	= AUD_ADC_PATH,
	Auto_Initialize.AUD_DAC_PATH	= AUD_DAC_PATH,
	Auto_Initialize.AUD_POWER		= AUD_POWER,
	Auto_Initialize.AUD_DATA_FORMAT	= AUD_DATA_FORMAT,
	Auto_Initialize.AUD_SAMPLE_CTRL	= AUD_SAMPLE_CTRL,
	Auto_Initialize.AUD_SET_ACTIVE	= AUD_SET_ACTIVE;

Altera_UP_I2C I2C_Controller (
	// Inputs
	.clk					(clk),
	.reset					(internal_reset),

	.clear_ack				(clear_status_bits),

	.clk_400KHz				(clk_400KHz),
	.start_and_stop_en		(start_and_stop_en),
	.change_output_bit_en	(change_output_bit_en),

	.send_start_bit			(send_start_bit),
	.send_stop_bit			(send_stop_bit),

	.data_in				(data_to_transfer),
	.transfer_data			(transfer_data),
	.read_byte				(read_byte),
	.num_bits_to_transfer	(num_bits_to_transfer),

	// Bidirectionals
	.i2c_sdata				(I2C_SDAT),

	// Outputs
	.i2c_sclk				(I2C_SCLK),
	.i2c_scen				(),

	.enable_clk				(enable_clk),

	.ack					(i2c_ack),
	.data_from_i2c			(i2c_received_data),
	.transfer_complete		(transfer_complete)
);
defparam
	I2C_Controller.I2C_BUS_MODE	= I2C_BUS_MODE;

endmodule

