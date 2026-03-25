`timescale 1ns / 1ps

import pcie_pkg::*; 
import register_controller_pkg::*;

module tb_register_router();

    // 1. Clock and Reset
    logic aclk;
    logic areset;

    // 2. Parameters for testing
    localparam int NUM_REQUESTS = 1;
    localparam bit [7:0] MY_FUNC_ID = 8'h01;
    localparam bit [2:0] MY_BAR_ID  = 3'h2;
    
    // 3. DUT Interfaces
    register_controller_t request;
    register_controller_t [NUM_REQUESTS-1:0] requests;
    register_controller_t outside_response;
    logic [63:0] base_address;

    
    register_router #(
        .NUM_REQUESTS(NUM_REQUESTS),
        .FUNCTION_ID(MY_FUNC_ID),
        .BAR_ID(MY_BAR_ID),
        // Region 0: 0x100 to 0x1FF 
        //Testing 1 Region to bypass Verilator array size limits
        .BASE_ADDR('{ 0: 64'h100 }), 
        .HIGH_ADDR('{ 0: 64'h1FF })
    ) dut (
        .request(request),
        .requests(requests),
        .outside_response(outside_response),
        .base_address(base_address),
        .aclk(aclk),
        .areset(areset)
    );

    // 5. Clock Generation
    initial begin
        aclk = 0;
        forever #2 aclk = ~aclk; 
    end


    initial begin
        //Dump Variables for Waveform
        $dumpfile("waveform_router.vcd");
        $dumpvars(0, tb_register_router);

        // Initialize
        areset = 1;
        base_address = 64'h0000_1000_0000_0000; // Simulated PCIe BAR base
        request = '0;

        #20 areset = 0;
        #20;
        @(posedge aclk);

        
        // Test 1: Valid Write to Region 0
        // Address = Base + 0x150. Should map to requests[0] with address 0x050.
        request.enable = 1'b1;
        request.write_enable = 1'b1;
        request.function_id = MY_FUNC_ID;
        request.bar_id = MY_BAR_ID;
        request.address = base_address + 64'h150;
        request.data = 32'hAAAA_BBBB;
        
        @(posedge aclk);
        request = '0; 
        @(posedge aclk);

        
        // Test 2: Valid Read from Region 0
        // Address = Base + 0x120. Should map to requests[0] with address 0x020.
        
        request.enable = 1'b1;
        request.write_enable = 1'b0; // Read
        request.function_id = MY_FUNC_ID;
        request.bar_id = MY_BAR_ID;
        request.address = base_address + 64'h120;
        
        @(posedge aclk);
        request = '0;
        @(posedge aclk);

        
        // Test 3: Invalid Read (Unmapped Region)
        // Address = Base + 0x500. Should map to outside_response with DEADBEEF.
        
        request.enable = 1'b1;
        request.write_enable = 1'b0; // Read
        request.function_id = MY_FUNC_ID;
        request.bar_id = MY_BAR_ID;
        request.address = base_address + 64'h500;
        
        @(posedge aclk);
        request = '0;
        
        #50;
        $display("Register Router Simulation Complete.");
        $finish;
    end

endmodule