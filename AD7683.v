// -----------------------------------------------------------------------------
//
// Copyright 2012(c) Analog Devices, Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//  - Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  - Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//  - Neither the name of Analog Devices, Inc. nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//  - The use of this software may or may not infringe the patent rights
//    of one or more patent holders.  This license does not release you
//    from the requirement that you obtain separate licenses from these
//    patent holders to use this software.
//  - Use of the software either in source or binary form, must be run
//    on or directly connected to an Analog Devices Inc. component.
//
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY
// AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// INTELLECTUAL PROPERTY RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// -----------------------------------------------------------------------------
// FILE NAME : AD7683.v
// MODULE NAME : AD7683
// AUTHOR :acostina
// AUTHOR’S EMAIL : adrian.costina@analog.com
// -----------------------------------------------------------------------------
// SVN REVISION: 1630
// -----------------------------------------------------------------------------
// KEYWORDS : AD7683
// -----------------------------------------------------------------------------
// PURPOSE : Driver for the AD7683 16-Bit Differential, 100 kSPS PulSAR ADC
//          MSOP/QFN
// -----------------------------------------------------------------------------
// REUSE ISSUES
// Reset Strategy      : Active low reset signal
// Clock Domains       :
// Critical Timing     : N/A
// Test Features       : N/A
// Asynchronous I/F    : N/A
// Instantiations      : N/A
// Synthesizable (y/n) : Y
// Target Device       : AD7683
// Other               : The driver is intended to be used for AD7683 ADCs
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

`timescale 1 ns /100 ps //Use a timescale that is best for simulation.

//------------------------------------------------------------------------------
//----------- Module Declaration -----------------------------------------------
//------------------------------------------------------------------------------

module AD7683

//----------- Ports Declarations -----------------------------------------------
(
    //clock and reset signals
    input               fpga_clk_i,     // system clock
    input               reset_n_i,      // active low reset signal

    //IP control and data interface
    output     [15:0]   data_o,         // data read from the ADC
    output reg          data_rd_ready_o,// when set to high the data read from the ADC is available on the data_o bus

    //ADC control and data interface
    input               adc_dout_i,     // ADC DOUT signal
    output              adc_sclk_o,     // ADC DCLOCK signal
    output reg          adc_cs_n_o      // ADC CS signal
);

//------------------------------------------------------------------------------
//----------- Registers Declarations -------------------------------------------
//------------------------------------------------------------------------------

reg [ 3:0]  adc_state;      // current state for the ADC control state machine
reg [ 3:0]  adc_next_state; // next state for the ADC control state machine

reg [ 13:0]  adc_tcycle_cnt; // counts the number of FPGA clock cycles to determine when an ADC cycle is complete
reg [ 4:0]  sclk_clk_cnt;   // counts the number of clocks applied to the ADC to read the conversion result

reg [15:0]  adc_data_s;     // interal register used to store the data read from the ADC

reg [9:0]   div_clk_ff;     // counter used to divide clock
reg         adc_sclk_s;     // internal signal for the clock sent to the ADC

//------------------------------------------------------------------------------
//----------- Local Parameters -------------------------------------------------
//------------------------------------------------------------------------------
//ADC states
parameter ADC_IDLE_STATE        = 4'b0001;
parameter ADC_CONVERT_STATE     = 4'b0010;
parameter ADC_END_CNV_STATE     = 4'b0100;
parameter ADC_READ_CNV_RESULT   = 4'b1000;

//ADC timing
parameter real FPGA_CLOCK_FREQ  = 11.0592;  // FPGA clock frequency [MHz]100MHz=0.01us
parameter real ADC_CLOCK_FREQ   = 0.1728;  // ADC clock frequency [MHz] 2.3MHz=0.434us
parameter real ADC_CYCLE_TIME   = 1000;   // minimum time between two ADC conversions (Tcyc) [us] 10:CS's Falling edge =10us
parameter [13:0] ADC_CYCLE_CNT   = FPGA_CLOCK_FREQ * ADC_CYCLE_TIME - 1;
parameter [9:0] ADC_CLK_DIV     = FPGA_CLOCK_FREQ / ADC_CLOCK_FREQ / 2 - 1;

//ADC serial clock periods
parameter ADC_SCLK_PERIODS      = 5'd22; //number of clocks to be sent to the ADC to read the conversion result

//------------------------------------------------------------------------------
//----------- Assign/Always Blocks ---------------------------------------------
//------------------------------------------------------------------------------

assign adc_sclk_o     = adc_cs_n_o ? 1'b0 : adc_sclk_s;
assign data_o         = adc_data_s[15:0];

// Clock generation process
always @ (posedge fpga_clk_i)
begin
    if (reset_n_i == 1'b0)
    begin
        div_clk_ff  <= ADC_CLK_DIV;
        adc_sclk_s  <= 1'b0;
    end
    else
    begin
        if ( div_clk_ff == 10'h0)
        begin
            div_clk_ff <= ADC_CLK_DIV;
            adc_sclk_s <= ~adc_sclk_s;
        end
        else
        begin
            div_clk_ff <= div_clk_ff - 10'h1;
        end
    end
end

// Timing counter
always @(posedge fpga_clk_i)
begin
    if(reset_n_i == 1'b0)
    begin
        adc_tcycle_cnt  <= ADC_CYCLE_CNT;
    end
    else
    begin
        if(adc_tcycle_cnt != 13'h0)
        begin
            adc_tcycle_cnt <= adc_tcycle_cnt - 13'h1;
        end
        else if(adc_state == ADC_IDLE_STATE)
        begin
            adc_tcycle_cnt <= ADC_CYCLE_CNT;
        end
    end
end

// read data from the ADC
always @(posedge fpga_clk_i)
begin
    if(reset_n_i == 1'b0)
    begin
        adc_data_s  <= 16'h0;
        sclk_clk_cnt<= ADC_SCLK_PERIODS;
    end
    else if ( adc_state == ADC_CONVERT_STATE && adc_sclk_s == 1'b1 && div_clk_ff == 10'h10 )
    begin
        adc_data_s   <= { adc_data_s[14:0], adc_dout_i };
        sclk_clk_cnt <= sclk_clk_cnt - 5'h1;
    end
    else if ( adc_state == ADC_IDLE_STATE )
    begin
        sclk_clk_cnt <= ADC_SCLK_PERIODS;
    end
end

//update the ADC current state and the control signals
always @(posedge fpga_clk_i)
begin
    if(reset_n_i == 1'b0)
    begin
        adc_state <= ADC_IDLE_STATE;
    end
    else
    begin
        adc_state <= adc_next_state;
        case (adc_state)
            ADC_IDLE_STATE:     // Synchronize CS with DCLOCK
            begin
                adc_cs_n_o      <= 1'b1;
                data_rd_ready_o <= 1'b0;
            end
            ADC_CONVERT_STATE:  // Transfer data from the ADC
            begin
                adc_cs_n_o      <= 1'b0;
                data_rd_ready_o <= 1'b0;
            end
            ADC_READ_CNV_RESULT:// Transfer data to the upper module
            begin
                adc_cs_n_o      <= 1'b1;
                data_rd_ready_o <= 1'b1;
            end
            ADC_END_CNV_STATE:  // Wait for cycle end
            begin
                adc_cs_n_o      <= 1'b1;
                data_rd_ready_o <= 1'b0;
            end
        endcase
    end
end

//update the ADC next state
always @(adc_state, adc_sclk_s, adc_tcycle_cnt, div_clk_ff, sclk_clk_cnt)
begin
    adc_next_state = adc_state;
    case (adc_state)
        ADC_IDLE_STATE:
        begin
            if (adc_sclk_s == 1'b1 && div_clk_ff == 10'h0)
            begin
                adc_next_state = ADC_CONVERT_STATE;
            end
        end
        ADC_CONVERT_STATE:
        begin
            if (sclk_clk_cnt == 5'h0 && div_clk_ff == 10'h10)
            begin
                adc_next_state = ADC_READ_CNV_RESULT;
            end
        end
        ADC_READ_CNV_RESULT:
        begin
            adc_next_state  = ADC_END_CNV_STATE;
        end
        ADC_END_CNV_STATE:
        begin
            if( adc_tcycle_cnt == 13'h0)
            begin
                adc_next_state = ADC_IDLE_STATE;
            end
        end
        default:
        begin
            adc_next_state = ADC_IDLE_STATE;
        end
    endcase
end

endmodule
