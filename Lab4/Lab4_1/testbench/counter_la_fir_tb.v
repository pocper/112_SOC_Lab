// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`timescale 1 ns / 1 ps

module counter_la_fir_tb;
	reg clock;
    reg RSTB;
	reg CSB;

	reg power1, power2;

	wire gpio;
	wire uart_tx;
	wire [37:0] mprj_io;
	wire signed [15:0] checkbits;
	reg [15:0] pre_checkbits;

	assign checkbits  = mprj_io[31:16];
	assign uart_tx = mprj_io[6];

	always #12.5 clock <= (clock === 1'b0);

	initial begin
		clock = 0;
	end

	initial begin
		$dumpfile("./testbench/counter_la_fir.vcd");
		$dumpvars(0, counter_la_fir_tb);

		// Repeat cycles of 1000 clock edges as needed to complete testbench
		repeat (250) begin
			repeat (10000) @(posedge clock);
		end
		$display("%c[1;31m",27);
		`ifdef GL
			$display ("Monitor: Timeout, Test LA (GL) Failed");
		`else
			$display ("Monitor: Timeout, Test LA (RTL) Failed");
		`endif
		$display("%c[0m",27);
		$finish;
	end
	integer i = 0;
	initial begin
		pre_checkbits = 0;
		
		while (1) begin
			wait(checkbits != pre_checkbits);
			$display("Times = %2d, checkbits[dec] = %6d, checkbits[hex] = %4h", i, checkbits, checkbits);
			i = i + 1 ;
			pre_checkbits = checkbits;
			if (checkbits == 16'hAB40) begin
				$display("LA Test 1 started");
			end
			else if (checkbits == 16'hAB51) begin
				$display("LA Test 2 passed");
				$finish;
			end 
		end
	end

	initial begin
		RSTB <= 1'b0;
		CSB  <= 1'b1;		// Force CSB high
		#2000;
		RSTB <= 1'b1;	    	// Release reset
		#170000;
		CSB = 1'b0;		// CSB can be released
	end

	initial begin		// Power-up sequence
		power1 <= 1'b0;
		power2 <= 1'b0;
		#200;
		power1 <= 1'b1;
		#200;
		power2 <= 1'b1;
	end

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;

	wire VDD1V8;
	wire VDD3V3;
	wire VSS;
    
	assign VDD3V3 = power1;
	assign VDD1V8 = power2;
	assign VSS = 1'b0;

	assign mprj_io[3] = 1;  // Force CSB high.
	assign mprj_io[0] = 0;  // Disable debug mode

	caravel uut (
		.clock    (clock),
		.gpio     (gpio),
		.mprj_io  (mprj_io),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.resetb	  (RSTB)
	);

	spiflash #(
		.FILENAME("./testbench/counter_la_fir.hex")//load compiled counter_la_fir.c(counter_la_fir.hex) to spiflash then executed by CPU
	) spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(),			// not used
		.io3()			// not used
	);

	// Testbench UART
	tbuart tbuart (
		.ser_rx(uart_tx)
	);

endmodule
`default_nettype wire
