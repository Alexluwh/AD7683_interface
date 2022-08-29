// Copyright (C) 1991-2011 Altera Corporation
// Your use of Altera Corporation's design tools, logic functions
// and other software and tools, and its AMPP partner logic
// functions, and any output files from any of the foregoing
// (including device programming or simulation files), and any
// associated documentation or information are expressly subject
// to the terms and conditions of the Altera Program License
// Subscription Agreement, Altera MegaCore Function License
// Agreement, or other applicable license agreement, including,
// without limitation, that your use is for the sole purpose of
// programming logic devices manufactured by Altera and sold by
// Altera or its authorized distributors.  Please refer to the
// applicable agreement for further details.

// *****************************************************************************
// This file contains a Verilog test bench template that is freely editable to
// suit user's needs .Comments are provided in each section to help the user
// fill out necessary details.
// *****************************************************************************
// Generated on "12/16/2011 13:00:55"

// Verilog Test Bench template for design : AD7683
//
// Simulation tool : ModelSim-Altera (Verilog)
//

`timescale 1 ns/ 1 ps
module AD7683_vlg_tst();
// test vector input registers
reg adc_dout_i;
reg fpga_clk_i;
reg reset_n_i;
// wires
wire adc_cs_n_o;
wire adc_sclk_o;
wire [15:0]  data_o;
wire data_rd_ready_o;
reg [20:0] adc_data;

// assign statements (if any)
AD7683 i1 (
// port map - connection between master ports and signals/registers
    .adc_cs_n_o(adc_cs_n_o),
    .adc_sclk_o(adc_sclk_o),
    .adc_dout_i(adc_dout_i),
    .data_o(data_o),
    .data_rd_ready_o(data_rd_ready_o),
    .fpga_clk_i(fpga_clk_i),
    .reset_n_i(reset_n_i)
);
initial
begin
    fpga_clk_i = 1'b0;
    reset_n_i  = 1'b0;
    adc_data   = 21'h008080;
#100
    reset_n_i = 1'b1;
$display("Running testbench");
end

//main clock generation
always
begin
    #45.211 fpga_clk_i <= ~fpga_clk_i;
end

//simulate ADC behaviour
always @(posedge adc_cs_n_o)
begin
    adc_data    = adc_data + 1;
end

always @(negedge adc_sclk_o)
begin
    if (adc_cs_n_o == 1'b0)
    begin
        //tHDO
        #5
        adc_dout_i  = 1'bX;
        //tEN
        #45
        adc_dout_i  = adc_data[20];
        adc_data    = {adc_data[19:0], adc_data[20]};
    end
    else
    begin
        #100
        adc_dout_i  = 1'bZ;
    end
end

endmodule

