`timescale 1ns / 1ps

import pcie_pkg::*;
import pcie_rc_pkg::*;

module tb_rc_parser();

    // 1. Clock and Reset
    logic aclk;
    logic areset;

    // 2.Inputs
    logic [511:0] s_axis_rc_data;
    rc_user_t     s_axis_rc_user;
    logic         s_axis_rc_last;
    logic         s_axis_rc_valid;

    // 3.Outputs
    rc_tlp_t   tlp;
    rc_tlp_0_t tlp_0;
    rc_tlp_1_t tlp_1;
    rc_tlp_2_t tlp_2;
    rc_tlp_3_t tlp_3;
    logic      tlp_enable;
    logic      tlp_enable_0;
    logic      tlp_enable_1;
    logic      tlp_enable_2;
    logic      tlp_enable_3;

    
    rc_parser dut (
        .s_axis_rc_data(s_axis_rc_data),
        .s_axis_rc_user(s_axis_rc_user),
        .s_axis_rc_last(s_axis_rc_last),
        .s_axis_rc_valid(s_axis_rc_valid),
        .tlp(tlp),
        .tlp_0(tlp_0),
        .tlp_1(tlp_1),
        .tlp_2(tlp_2),
        .tlp_3(tlp_3),
        .tlp_enable(tlp_enable),
        .tlp_enable_0(tlp_enable_0),
        .tlp_enable_1(tlp_enable_1),
        .tlp_enable_2(tlp_enable_2),
        .tlp_enable_3(tlp_enable_3),
        .aclk(aclk),
        .areset(areset)
    );

    // 5. Clock Generation
    initial begin
        aclk = 0;
        forever #2 aclk = ~aclk; 
    end

    // 6. Stimulus Variables
    rc_descriptor_t my_desc;
    rc_user_t       my_user;

    
    initial begin
        //Dump Variables for Waveform
        $dumpfile("waveform_rc.vcd");
        $dumpvars(0, tb_rc_parser);

        
        areset = 1;
        s_axis_rc_valid = 0;
        s_axis_rc_last = 0;
        s_axis_rc_data = '0;
        s_axis_rc_user = '0;

        
        #20 areset = 0;
        #20;
        @(posedge aclk);

        
        //Test : Single Completion with Data (CplD) (Simulating the Host PC returning 1 DWORD of DMA data)
        // A. Build the 96-bit RC Descriptor
        my_desc = '0; 
        my_desc.lower_address          = 12'h000;
        my_desc.error_code             = ERR_NORMAL_TERMINATION;
        my_desc.byte_count             = 13'd4; // 4 bytes returning
        my_desc.locked_read_completion = 1'b0;
        my_desc.request_completed      = 1'b1;
        my_desc.dword_count            = 11'd1; // 1 DWORD of payload
        my_desc.completion_status      = COMPLETION_STATUS_SC; // Success!
        my_desc.poisoned_completion    = 1'b0;
        my_desc.requester_id           = 16'h0100; // FPGA ID
        my_desc.tag                    = 8'hAA;    // Must match the original request tag
        my_desc.completer_id           = 16'h0200; // Host PC ID

        // B. Build the User (Sideband) Signals
        my_user = '0;
        
        // We are sending 1 packet starting at the very beginning of the bus
        my_user.is_sop = 4'b0001;  // Start of packet valid in slot 0
        my_user.is_eop = 4'b0001;  // End of packet valid in slot 0
        
        my_user.is_sop_ptr[0] = 2'b00; // Packet starts exactly at DWORD 0
        
        // Descriptor is 3 DWORDS (0, 1, 2). Payload is 1 DWORD (3).
        // Therefore, the packet ends at DWORD 3.
        my_user.is_eop_ptr[0] = 4'd3;  

        // C. Pack everything onto the 512-bit bus
        s_axis_rc_valid = 1'b1;
        s_axis_rc_last  = 1'b1; 
        s_axis_rc_user  = my_user;
        
        // Descriptor goes in bits [95:0]
        s_axis_rc_data[95:0]    = my_desc;      
        
        // The 32-bit (1 DWORD) Payload goes right after the descriptor in bits [127:96]
        s_axis_rc_data[127:96]  = 32'hCAFEBABE; 

        // Drive for one clock cycle
        @(posedge aclk);
        s_axis_rc_valid = 1'b0;
        s_axis_rc_last  = 1'b0;
        s_axis_rc_data  = '0;
        #50;
        
        $display("RC Parser Simulation Complete.");
        $finish;
    end

endmodule