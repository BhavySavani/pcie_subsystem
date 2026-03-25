`timescale 1ns / 1ps
//Import Packages
import pcie_pkg::*;
import pcie_cq_pkg::*;

module tb_cq_parser();

    // 1. Clock and Reset
    logic clk;
    logic areset;

    // 2. Inputs
    logic [511:0] s_axis_cq_data;
    cq_user_t     s_axis_cq_user;
    logic         s_axis_cq_last;
    logic         s_axis_cq_valid;

    // 3. Outputs
    cq_tlp_t      tlp;
    logic         tlp_enable;

    
    cq_parser_non_straddle dut (
        .s_axis_cq_data(s_axis_cq_data),
        .s_axis_cq_user(s_axis_cq_user),
        .s_axis_cq_last(s_axis_cq_last),
        .s_axis_cq_valid(s_axis_cq_valid),
        .tlp(tlp),
        .tlp_enable(tlp_enable),
        .aclk(clk),
        .areset(areset)
    );

    
    initial begin
        clk = 0;
        forever #2 clk = ~clk; 
    end

    // 6. Stimulus Variables
    cq_mem_descriptor_t my_desc;
    cq_user_t           my_user;

    // 7. Test Sequence
    initial begin
        $dumpfile("waveform_cq.vcd");
        $dumpvars(0, tb_cq_parser);
        // Initialize
        areset = 1;
        s_axis_cq_valid = 0;
        s_axis_cq_last = 0;
        s_axis_cq_data = '0;
        s_axis_cq_user = '0;

        // Release reset
        #20 areset = 0;
        #20;
        @(posedge clk);

        //Test : Single-DWORD Memory Write
        
        // A. Build the Descriptor
        my_desc = '0; // Clear all fields
        my_desc.request_type = REQUEST_MEM_WRITE;
        my_desc.address_type = ADDRESS_TYPE_UNTRANSLATED;
        my_desc.address      = 62'h0000_0000_0000_0400; // Target Address: 0x1000
        my_desc.dword_count  = 11'd1;                   // 1 DWORD (4 bytes) of payload
        my_desc.requester_id = 16'h0100;                // Bus 1, Dev 0, Func 0
        my_desc.tag          = 8'hAA;                   // Arbitrary transaction tag

        // B. Build the User (Sideband) Signals
        my_user = '0;
        my_user.first_be      = 8'h0F;  // All 4 bytes of the first payload DWORD are valid
        my_user.last_be       = 8'h00;  // Single DWORD payload, so last_be is 0
        my_user.is_sop        = 2'b01;  // Start of Packet on bit 0 of the bus
        my_user.is_eop        = 2'b01;  // End of Packet on this beat
        
        // The descriptor takes up DWORDS 0, 1, 2, and 3 (128 bits).
        // Our 1 DWORD payload sits at DWORD 4.
        my_user.is_eop_ptr[0] = 4'd4;   // Tell the core the packet ends at DWORD 4

        // C. Pack everything onto the 512-bit bus
        s_axis_cq_valid = 1'b1;
        s_axis_cq_last  = 1'b1;         // Entire packet fits in one 512-bit cycle
        s_axis_cq_user  = my_user;
        
        s_axis_cq_data[127:0]   = my_desc;      // 128-bit header goes in the LSBs
        s_axis_cq_data[159:128] = 32'hDEADBEEF; // 32-bit Payload goes right after

        // Drive for one clock cycle
        @(posedge clk);
        s_axis_cq_valid = 1'b0;
        s_axis_cq_last  = 1'b0;
        s_axis_cq_data  = '0;

        // Wait a few cycles to observe the output
        #50;
        
        $display("Simulation Complete.");
        $finish;
    end

endmodule