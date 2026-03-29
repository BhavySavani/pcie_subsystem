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
    logic [63:0] s_axis_cq_keep;
    
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

   
    // Task: Send an AXI-Stream Beat
    task send_beat(input logic [511:0] data, input logic [63:0] keep, input logic last, input logic discontinue = 0);
        s_axis_cq_valid = 1'b1;
        s_axis_cq_data  = data;
        s_axis_cq_keep  = keep; 
        s_axis_cq_last  = last;
        
        s_axis_cq_user  = '0; 
        if (discontinue) s_axis_cq_user[41] = 1'b1; 

        @(posedge clk);

        s_axis_cq_valid = 1'b0;
    endtask

    
    initial begin

        areset = 1;
        s_axis_cq_valid = 0;
        #20 areset = 0;
        #20;
        @(posedge clk);

        $display(">>> Starting CQ Parser Verification Suite...");

        // ---------------------------------------------------------
        // TEST 1: Mem Read (128b Descriptor, 0b Payload)
        // 128 bits = 16 bytes. TKEEP = 0x0000_0000_0000_FFFF
        // ---------------------------------------------------------
        $display("Test 1: Mem Read (0b Payload)");
        send_beat(
            {384'h0, 128'h00000000_00001000_00000000_40000000}, // Simulated Descriptor
            64'h0000_0000_0000_FFFF, 
            1'b1 
        );
        #20;

        // ---------------------------------------------------------
        // TEST 2: Mem Write (128b Descriptor, 32b Payload)
        // 160 bits = 20 bytes. TKEEP = 0x0000_0000_000F_FFFF
        // ---------------------------------------------------------
        $display("Test 2: Mem Write (32b Payload)");
        send_beat(
            {352'h0, 32'hDEADBEEF, 128'h00000000_00001000_00000000_40000001}, 
            64'h0000_0000_000F_FFFF, 
            1'b1 
        );
        #20;

        // ---------------------------------------------------------
        // TEST 3: Mem Write (128b Descriptor, 384b Payload)
        // 512 bits = 64 bytes. TKEEP = 0xFFFF_FFFF_FFFF_FFFF (All 1s)
        // Fits perfectly in exactly one beat!
        // ---------------------------------------------------------
        $display("Test 3: Mem Write (384b Payload - 1 Beat Exact)");
        send_beat(
            {{12{32'hAAAA_BBBB}}, 128'h00000000_00001000_00000000_4000000C}, 
            64'hFFFF_FFFF_FFFF_FFFF, 
            1'b1 
        );
        #20;

        // ---------------------------------------------------------
        // TEST 4: Mem Write (128b Descriptor, 416b Payload)
        // Spills over into a second beat!
        // ---------------------------------------------------------
        $display("Test 4: Mem Write (416b Payload - 2 Beats)");
        // Beat 1: Descriptor + First 384 bits of payload
        send_beat(
            {{12{32'h1111_2222}}, 128'h00000000_00001000_00000000_4000000D}, 
            64'hFFFF_FFFF_FFFF_FFFF, 
            1'b0 
        );
        // Remaining 32 bits of payload (4 bytes -> TKEEP = 0xF)
        send_beat(
            {480'h0, 32'h3333_4444}, 
            64'h0000_0000_0000_000F, 
            1'b1 
        );
        #20;

        // ---------------------------------------------------------
        // TEST 5: Mem Write (128b Descriptor, 8192b Payload)
        // 8192 bits = 1024 bytes (256 DWORDs).
        // Requires 17 total beats.
        // ---------------------------------------------------------
        $display("Test 5: Mem Write Burst (8192b Payload - 17 Beats)");
        // Beat 1: Descriptor + First 384 bits
        send_beat({ {12{32'hFACE_FEED}}, 128'h00000000_00001000_00000000_40000100}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
        
        // Beats 2 to 16: 512 bits of pure payload per beat
        for (int i = 0; i < 15; i++) begin
            send_beat({16{32'hCAFE_BABE}}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
        end
        
        // Beat 17: Final 128 bits of payload (16 bytes -> TKEEP = 0xFFFF)
        send_beat({384'h0, {4{32'hBEEF_CAFE}}}, 64'h0000_0000_0000_FFFF, 1'b1);
        #20;

        // ---------------------------------------------------------
        // TEST 6: Discontinue Assertion (TLP Drop)
        // Simulating a corrupted packet that the host aborts mid-flight.
        // ---------------------------------------------------------
        $display("Test 6: Discontinue Packet (TLP Drop)");
        send_beat(
            {352'h0, 32'hBAD0_BAD0, 128'h00000000_00001000_00000000_40000001}, 
            64'h0000_0000_000F_FFFF, 
            1'b1, 
            1'b1 // Set discontinue flag!
        );
        #50;

        $display(">>> CQ Parser Verification Suite Complete!");
        $finish;
    end

endmodule: tb_cq_parser
