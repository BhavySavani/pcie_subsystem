`timescale 1ns / 1ps

import pcie_cq_pkg::cq_tlp_t;
import pcie_cq_pkg::cq_user_t;

module cq_parser_non_straddle (
  input [511:0]   s_axis_cq_data,
  input cq_user_t s_axis_cq_user,
  input           s_axis_cq_last,
  input           s_axis_cq_valid,

  output cq_tlp_t tlp,
  output logic    tlp_enable,

  input aclk,
  input areset
);

  typedef struct packed {
    logic [4:0]    index;
    logic [8703:0] data;
  } continue_t;
  continue_t c;

  always_comb begin
    tlp = '0;
    tlp_enable = 1'b0;
    if (s_axis_cq_valid && s_axis_cq_last && !s_axis_cq_user.discontinue) begin
      tlp = c.data;
      tlp[c.index * 512 +: 512] = s_axis_cq_data;
      tlp_enable = 1'b1;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      c <= '0;
    end else begin
      if (s_axis_cq_valid) begin
        c <= parse_for_continue(c, s_axis_cq_data, s_axis_cq_last);
      end
    end
  end

function automatic logic [8708:0] parse_for_continue(
    input continue_t    now_continue,
    input logic [511:0] data,
    input logic         last
  );
    continue_t next_continue = '0;

    if (!last) begin
      // Fix : Preserve previously accumulated payload data
      next_continue.data = now_continue.data;                       
      next_continue.data[now_continue.index * 512 +: 512] = data;
      next_continue.index = now_continue.index + 1;
    end

    return next_continue;
  endfunction

endmodule: cq_parser_non_straddle
