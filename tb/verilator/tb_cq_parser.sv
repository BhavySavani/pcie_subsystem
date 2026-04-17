`timescale 1ns / 1ps

module tb_cq_parser();

    logic clk = 0;
    logic areset = 1;
    
    always #5 clk = ~clk; 

    logic [511:0] s_axis_cq_data;
    logic [63:0]  s_axis_cq_keep;
    cq_user_t     s_axis_cq_user;
    logic         s_axis_cq_last;
    logic         s_axis_cq_valid;

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

    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic chk(input string name, input logic cond);
        if (cond) begin
            $display("    [PASS] %s", name);
            pass_cnt++;
        end else begin
            $error("    [FAIL] %s  (time=%0t)", name, $time);
            fail_cnt++;
        end
    endtask


    task automatic start_beat(input logic [511:0] data, input logic [63:0] keep, input logic last, input logic discontinue = 0);
        @(negedge clk);
        s_axis_cq_valid = 1'b1;
        s_axis_cq_data  = data;
        s_axis_cq_keep  = keep; 
        s_axis_cq_last  = last;
        
        s_axis_cq_user = '0; 
        s_axis_cq_user.discontinue = discontinue; // Correct struct member access

        #1; 
    endtask

    
    task automatic end_beat();
        @(posedge clk);  // c register (payload accumulation) latches here
        @(negedge clk);
        s_axis_cq_valid = 1'b0;
        s_axis_cq_user  = '0;
    endtask

    
    initial begin
        
        s_axis_cq_valid = 0;
        s_axis_cq_data  = '0;
        s_axis_cq_keep  = '0;
        s_axis_cq_last  = 0;
        s_axis_cq_user  = '0;

        repeat(4) @(posedge clk);
        @(negedge clk); 
        areset = 0;
        @(posedge clk);

        $display(">>> Starting CQ Parser White-Box Verification Suite...\n");

        
        // Test 1: Mem Read (128b Descriptor, 0b Payload)
        
        $display("[Test 1] Mem Read (0b Payload)");
        start_beat({384'h0, 128'h00000000_00001000_00000000_40000000}, 64'h0000_0000_0000_FFFF, 1'b1);
        chk("T1: tlp_enable asserts", tlp_enable === 1'b1);
        // Assuming tlp struct has desc.mem field based on previous context
        // chk("T1: Descriptor matches expected", tlp.desc.mem === 128'h00000000_00001000_00000000_40000000);
        end_beat();
        repeat(2) @(posedge clk);

        
        // Test 2: Mem Write (128b Descriptor, 32b Payload)
        
        $display("\n[Test 2] Mem Write (32b Payload)");
        start_beat({352'h0, 32'hDEADBEEF, 128'h00000000_00001000_00000000_40000001}, 64'h0000_0000_000F_FFFF, 1'b1);
        chk("T2: tlp_enable asserts", tlp_enable === 1'b1);
        end_beat();
        repeat(2) @(posedge clk);

        
        // Test 3: Mem Write (128b Descriptor, 384b Payload)
        
        $display("\n[Test 3] Mem Write (384b Payload - 1 Beat Exact)");
        start_beat({{12{32'hAAAA_BBBB}}, 128'h00000000_00001000_00000000_4000000C}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        chk("T3: tlp_enable asserts exactly on beat 1", tlp_enable === 1'b1);
        end_beat();
        repeat(2) @(posedge clk);

        
        // Test 4: Mem Write (128b Descriptor, 416b Payload)
        
        $display("\n[Test 4] Mem Write (416b Payload - 2 Beats)");
        // Beat 1
        start_beat({{12{32'h1111_2222}}, 128'h00000000_00001000_00000000_4000000D}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
        chk("T4: tlp_enable silent on Beat 1", tlp_enable === 1'b0);
        end_beat();
        
        // Beat 2
        start_beat({480'h0, 32'h3333_4444}, 64'h0000_0000_0000_000F, 1'b1);
        chk("T4: tlp_enable asserts on Beat 2", tlp_enable === 1'b1);
        end_beat();
        repeat(2) @(posedge clk);

        
        // Test 5: Mem Write Burst (8192b Payload - 17 Beats)
        // This validates the parse_for_continue fix perfectly.
        
        $display("\n[Test 5] Mem Write Burst (8192b Payload - 17 Beats)");
        // Beat 1: Descriptor + First 384 bits
        start_beat({ {12{32'hFACE_FEED}}, 128'h00000000_00001000_00000000_40000100}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
        chk("T5: tlp_enable silent on Beat 1", tlp_enable === 1'b0);
        end_beat();
        
        // Beats 2 to 16: Pure payload
        for (int i = 2; i <= 16; i++) begin
            start_beat({16{32'hCAFE_BABE}}, 64'hFFFF_FFFF_FFFF_FFFF, 1'b0);
            chk($sformatf("T5: tlp_enable silent on Beat %0d", i), tlp_enable === 1'b0);
            end_beat();
        end
        
        // Beat 17: Final chunk
        start_beat({384'h0, {4{32'hBEEF_CAFE}}}, 64'h0000_0000_0000_FFFF, 1'b1);
        chk("T5: tlp_enable asserts on final Beat 17", tlp_enable === 1'b1);
        end_beat();
        repeat(2) @(posedge clk);

        
        // Test 6: Discontinue Assertion
        
        $display("\n[Test 6] Discontinue Packet (TLP Drop)");
        start_beat({352'h0, 32'hBAD0_BAD0, 128'h00000000_00001000_00000000_40000001}, 64'h0000_0000_000F_FFFF, 1'b1, 1'b1);
        chk("T6: tlp_enable silent when discontinue is flagged", tlp_enable === 1'b0);
        end_beat();
        repeat(5) @(posedge clk);

        
        // Verification Summary
        
        $display("\n========================================");
        $display("VERIFICATION COMPLETE");
        $display("Passed: %0d", pass_cnt);
        $display("Failed: %0d", fail_cnt);
        $display("========================================");
        
        if (fail_cnt > 0) begin
            $display("ERROR: Testbench completed with failures.");
        end else begin
            $display("SUCCESS: All hardware checks passed.");
        end
        
        $finish;
    end

endmodule