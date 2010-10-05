
//-----------------------------------------------------------------------------
//
// (c) Copyright 2009 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information of Xilinx, Inc.
// and is protected under U.S. and international copyright and other
// intellectual property laws.
//
// DISCLAIMER
//
// This disclaimer is not a license and does not grant any rights to the
// materials distributed herewith. Except as otherwise provided in a valid
// license issued to you by Xilinx, and to the maximum extent permitted by
// applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL
// FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS,
// IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
// MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE;
// and (2) Xilinx shall not be liable (whether in contract or tort, including
// negligence, or under any other theory of liability) for any loss or damage
// of any kind or nature related to, arising under or in connection with these
// materials, including for any direct, or any indirect, special, incidental,
// or consequential loss or damage (including loss of data, profits, goodwill,
// or any type of loss or damage suffered as a result of any action brought by
// a third party) even if such damage or loss was reasonably foreseeable or
// Xilinx had been advised of the possibility of the same.
//
// CRITICAL APPLICATIONS
//
// Xilinx products are not designed or intended to be fail-safe, or for use in
// any application requiring fail-safe performance, such as life-support or
// safety devices or systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any other
// applications that could lead to death, personal injury, or severe property
// or environmental damage (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and liability of any use of
// Xilinx products in Critical Applications, subject only to applicable laws
// and regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE
// AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : V5-Block Plus for PCI Express
// File       : prod_fixes.v
//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
//
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor      : Xilinx
// \   \   \/     Version     : 1.1
//  \   \         Application : Generated by Xilinx PCI Express Wizard
//  /   /         Filename    : prod_fixes.v
// /___/   /\     Module      : Snoop and Fix Production Issues
// \   \  /  \
//  \___\/\___\
//
//------------------------------------------------------------------------------

// PCIE Spec 2.0 Gen2 upconfigure capable TS2 bit 6 workaround.
// Force all reserved fields in TS1 and TS2s to 0 on PCIe block 
// receive path on all lanes when in Polling and Configuration.

module prod_fixes
(
   input            clk,
   input            bit_reset_n,
   input  [3:0]     l0_ltssm_state,
   input            chan_bond_done,
   input  [3:0]     negotiated_link_width,
   input	    trn_lnk_up_n,

   // for pipelining
   input  [7:0]     pipe_rx_data_k,
   input  [7:0]     pipe_rx_valid,
   
   input  [7:0]     pipe_rx_data_l0,
   input  [7:0]     pipe_rx_data_l1,
   input  [7:0]     pipe_rx_data_l2,
   input  [7:0]     pipe_rx_data_l3,
   input  [7:0]     pipe_rx_data_l4,
   input  [7:0]     pipe_rx_data_l5,
   input  [7:0]     pipe_rx_data_l6,
   input  [7:0]     pipe_rx_data_l7,

   output reg [7:0]    pipe_rx_data_l0_out, 
   output reg [7:0]    pipe_rx_data_l1_out, 
   output reg [7:0]    pipe_rx_data_l2_out, 
   output reg [7:0]    pipe_rx_data_l3_out, 
   output reg [7:0]    pipe_rx_data_l4_out, 
   output reg [7:0]    pipe_rx_data_l5_out, 
   output reg [7:0]    pipe_rx_data_l6_out, 
   output reg [7:0]    pipe_rx_data_l7_out,
   output              upcfgcap_cycle,    
   output              masking_ack,
   output reg [7:0]    pipe_rx_data_k_out,
   output reg [7:0]    pipe_rx_valid_out

);

   parameter STATE_SIZE = 5;
   parameter [STATE_SIZE-1:0] 
                   ALGN     = 'h1,
                   Q_TS     = 'h2,
                   SYM2     = 'h4,
                   SYM3     = 'h8,
                   SYM4     = 'h10;
   
   parameter [8:0] PAD       = 9'h1F7;
   parameter [8:0] COM       = 9'h1BC;
   parameter [8:0] SKP       = 9'h11C;
   parameter [8:0] IDL       = 9'h17C;
   parameter [8:0] SDP       = 9'h15C;
   parameter [8:0] END       = 9'h1FD;
   
   parameter [3:0] LT_POLLING  = 4'b0010;
   parameter [3:0] LT_CONFIG   = 4'b0011;
   parameter [3:0] LT_RECOVERY = 4'b1100;
   
   parameter       IS_D = 1'b0;
   parameter       IS_K = 1'b1;
   
   reg  [STATE_SIZE-1:0]  
                   curr_state_l0, next_state_l0,
                   curr_state_l1, next_state_l1,
                   curr_state_l2, next_state_l2,
                   curr_state_l3, next_state_l3,
                   curr_state_l4, next_state_l4,
                   curr_state_l5, next_state_l5,
                   curr_state_l6, next_state_l6,
                   curr_state_l7, next_state_l7;
                   
   wire [8:0]      l0_pipe_rx_input;
   wire [8:0]      l1_pipe_rx_input;
   wire [8:0]      l2_pipe_rx_input;
   wire [8:0]      l3_pipe_rx_input;
   wire [8:0]      l4_pipe_rx_input;
   wire [8:0]      l5_pipe_rx_input;
   wire [8:0]      l6_pipe_rx_input;
   wire [8:0]      l7_pipe_rx_input;
   reg             dllp_ack_l0 = 1'b0;
   reg             dllp_ack_l4 = 1'b0;
   reg             dllp_ack_l0_r = 1'b0;
   reg             dllp_ack_l4_r = 1'b0;
   reg             dllp_ack_l4_rr = 1'b0;

   reg             dllp_ack_l7_reverse = 1'b0;
   reg             dllp_ack_l3_reverse= 1'b0;
   reg             dllp_ack_l7_reverse_r = 1'b0;
   reg             dllp_ack_l3_reverse_r = 1'b0;
   reg             dllp_ack_l3_reverse_rr = 1'b0;

   reg  [3:0]      l0_ltssm_state_d;
   reg             trn_lnk_up_n_d;

   reg  [7:0]      seq_num_xor_curr = 8'h0;
   reg  [7:0]      seq_num_xor_prev = 8'h0;   

   reg  [3:0]      negotiated_link_width_d; 
   
   integer i = 0;
   
   assign l0_pipe_rx_input = {pipe_rx_data_k[0], pipe_rx_data_l0};
   assign l1_pipe_rx_input = {pipe_rx_data_k[1], pipe_rx_data_l1};
   assign l2_pipe_rx_input = {pipe_rx_data_k[2], pipe_rx_data_l2};      
   assign l3_pipe_rx_input = {pipe_rx_data_k[3], pipe_rx_data_l3};
   assign l4_pipe_rx_input = {pipe_rx_data_k[4], pipe_rx_data_l4};
   assign l5_pipe_rx_input = {pipe_rx_data_k[5], pipe_rx_data_l5};
   assign l6_pipe_rx_input = {pipe_rx_data_k[6], pipe_rx_data_l6};      
   assign l7_pipe_rx_input = {pipe_rx_data_k[7], pipe_rx_data_l7};

   reg          upcfgcap_cycle_l0; 
   reg          upcfgcap_cycle_l1; 
   reg          upcfgcap_cycle_l2;
   reg          upcfgcap_cycle_l3;
   reg          upcfgcap_cycle_l4;
   reg          upcfgcap_cycle_l5;
   reg          upcfgcap_cycle_l6;
   reg          upcfgcap_cycle_l7;  


   always @(posedge clk) 
   begin : REGISTER_LTSSM_STATE
      if (!bit_reset_n)
      begin
         l0_ltssm_state_d <= 4'b0;
         trn_lnk_up_n_d   <= 1'b1;
      end else begin
         l0_ltssm_state_d <= l0_ltssm_state;
         trn_lnk_up_n_d   <= trn_lnk_up_n;
      end
   end



////////////////////////////Lane 0///////////////////// 
   always @(curr_state_l0, l0_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L0


      case (curr_state_l0)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l0_pipe_rx_input == COM) begin
                
                next_state_l0 <= Q_TS;
                upcfgcap_cycle_l0 <= 1'b0;
            end else begin
                
                next_state_l0 <= ALGN;
                upcfgcap_cycle_l0 <= 1'b0;
            
            end
      Q_TS: if (l0_pipe_rx_input == PAD || l0_pipe_rx_input[8] == IS_D) begin
                
                next_state_l0 <= SYM2;
                upcfgcap_cycle_l0 <= 1'b0;
            
            end else begin
                
                next_state_l0 <= ALGN;
                upcfgcap_cycle_l0 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l0 <= SYM3;
                upcfgcap_cycle_l0 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l0 <= SYM4;
                upcfgcap_cycle_l0 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l0 <= ALGN;
                upcfgcap_cycle_l0 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l0 <= ALGN;
                upcfgcap_cycle_l0 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L0
      if (!bit_reset_n)
         curr_state_l0 <= ALGN;
      else
         curr_state_l0 <= next_state_l0;
   end


////////////////////////////Lane 1///////////////////// 
   always @(curr_state_l1, l1_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L1


      case (curr_state_l1)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l1_pipe_rx_input == COM) begin
                
                next_state_l1 <= Q_TS;
                upcfgcap_cycle_l1 <= 1'b0;
            end else begin
                
                next_state_l1 <= ALGN;
                upcfgcap_cycle_l1 <= 1'b0;
            
            end
      Q_TS: if (l1_pipe_rx_input == PAD || l1_pipe_rx_input[8] == IS_D) begin
                
                next_state_l1 <= SYM2;
                upcfgcap_cycle_l1 <= 1'b0;
            
            end else begin
                
                next_state_l1 <= ALGN;
                upcfgcap_cycle_l1 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l1 <= SYM3;
                upcfgcap_cycle_l1 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l1 <= SYM4;
                upcfgcap_cycle_l1 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l1 <= ALGN;
                upcfgcap_cycle_l1 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l1 <= ALGN;
                upcfgcap_cycle_l1 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L1
      if (!bit_reset_n)
         curr_state_l1 <= ALGN;
      else
         curr_state_l1 <= next_state_l1;
   end



////////////////////////////Lane 2///////////////////// 
   always @(curr_state_l2, l2_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L2


      case (curr_state_l2)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l2_pipe_rx_input == COM) begin
                
                next_state_l2 <= Q_TS;
                upcfgcap_cycle_l2 <= 1'b0;
            end else begin
                
                next_state_l2 <= ALGN;
                upcfgcap_cycle_l2 <= 1'b0;
            
            end
      Q_TS: if (l2_pipe_rx_input == PAD || l2_pipe_rx_input[8] == IS_D) begin
                
                next_state_l2 <= SYM2;
                upcfgcap_cycle_l2 <= 1'b0;
            
            end else begin
                
                next_state_l2 <= ALGN;
                upcfgcap_cycle_l2 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l2 <= SYM3;
                upcfgcap_cycle_l2 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l2 <= SYM4;
                upcfgcap_cycle_l2 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l2 <= ALGN;
                upcfgcap_cycle_l2 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l2 <= ALGN;
                upcfgcap_cycle_l2 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L2
      if (!bit_reset_n)
         curr_state_l2 <= ALGN;
      else
         curr_state_l2 <= next_state_l2;
   end



////////////////////////////Lane 3///////////////////// 
   always @(curr_state_l3, l3_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L3


      case (curr_state_l3)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l3_pipe_rx_input == COM) begin
                
                next_state_l3 <= Q_TS;
                upcfgcap_cycle_l3 <= 1'b0;
            end else begin
                
                next_state_l3 <= ALGN;
                upcfgcap_cycle_l3 <= 1'b0;
            
            end
      Q_TS: if (l3_pipe_rx_input == PAD || l3_pipe_rx_input[8] == IS_D) begin
                
                next_state_l3 <= SYM2;
                upcfgcap_cycle_l3 <= 1'b0;
            
            end else begin
                
                next_state_l3 <= ALGN;
                upcfgcap_cycle_l3 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l3 <= SYM3;
                upcfgcap_cycle_l3 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l3 <= SYM4;
                upcfgcap_cycle_l3 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l3 <= ALGN;
                upcfgcap_cycle_l3 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l3 <= ALGN;
                upcfgcap_cycle_l3 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L3
      if (!bit_reset_n)
         curr_state_l3 <= ALGN;
      else
         curr_state_l3 <= next_state_l3;
   end


////////////////////////////Lane 4///////////////////// 
   always @(curr_state_l4, l4_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L4


      case (curr_state_l4)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l4_pipe_rx_input == COM) begin
                
                next_state_l4 <= Q_TS;
                upcfgcap_cycle_l4 <= 1'b0;
            end else begin
                
                next_state_l4 <= ALGN;
                upcfgcap_cycle_l4 <= 1'b0;
            
            end
      Q_TS: if (l4_pipe_rx_input == PAD || l4_pipe_rx_input[8] == IS_D) begin
                
                next_state_l4 <= SYM2;
                upcfgcap_cycle_l4 <= 1'b0;
            
            end else begin
                
                next_state_l4 <= ALGN;
                upcfgcap_cycle_l4 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l4 <= SYM3;
                upcfgcap_cycle_l4 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l4 <= SYM4;
                upcfgcap_cycle_l4 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l4 <= ALGN;
                upcfgcap_cycle_l4 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l4 <= ALGN;
                upcfgcap_cycle_l4 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L4
      if (!bit_reset_n)
         curr_state_l4 <= ALGN;
      else
         curr_state_l4 <= next_state_l4;
   end


////////////////////////////Lane 5///////////////////// 
   always @(curr_state_l5, l5_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L5


      case (curr_state_l5)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l5_pipe_rx_input == COM) begin
                
                next_state_l5 <= Q_TS;
                upcfgcap_cycle_l5 <= 1'b0;
            end else begin
                
                next_state_l5 <= ALGN;
                upcfgcap_cycle_l5 <= 1'b0;
            
            end
      Q_TS: if (l5_pipe_rx_input == PAD || l5_pipe_rx_input[8] == IS_D) begin
                
                next_state_l5 <= SYM2;
                upcfgcap_cycle_l5 <= 1'b0;
            
            end else begin
                
                next_state_l5 <= ALGN;
                upcfgcap_cycle_l5 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l5 <= SYM3;
                upcfgcap_cycle_l5 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l5 <= SYM4;
                upcfgcap_cycle_l5 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l5 <= ALGN;
                upcfgcap_cycle_l5 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l5 <= ALGN;
                upcfgcap_cycle_l5 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L5
      if (!bit_reset_n)
         curr_state_l5 <= ALGN;
      else
         curr_state_l5 <= next_state_l5;
   end


////////////////////////////Lane 6///////////////////// 
   always @(curr_state_l6, l6_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L6


      case (curr_state_l6)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l6_pipe_rx_input == COM) begin
                
                next_state_l6 <= Q_TS;
                upcfgcap_cycle_l6 <= 1'b0;
            end else begin
                
                next_state_l6 <= ALGN;
                upcfgcap_cycle_l6 <= 1'b0;
            
            end
      Q_TS: if (l6_pipe_rx_input == PAD || l6_pipe_rx_input[8] == IS_D) begin
                
                next_state_l6 <= SYM2;
                upcfgcap_cycle_l6 <= 1'b0;
            
            end else begin
                
                next_state_l6 <= ALGN;
                upcfgcap_cycle_l6 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l6 <= SYM3;
                upcfgcap_cycle_l6 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l6 <= SYM4;
                upcfgcap_cycle_l6 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l6 <= ALGN;
                upcfgcap_cycle_l6 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l6 <= ALGN;
                upcfgcap_cycle_l6 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L6
      if (!bit_reset_n)
         curr_state_l6 <= ALGN;
      else
         curr_state_l6 <= next_state_l6;
   end

////////////////////////////Lane 7///////////////////// 
   always @(curr_state_l7, l7_pipe_rx_input, l0_ltssm_state_d)
   begin: FSM_COMB_L7


      case (curr_state_l7)
      

      ALGN: if ((l0_ltssm_state_d == LT_CONFIG || l0_ltssm_state_d == LT_RECOVERY
                || l0_ltssm_state_d == LT_POLLING) 
                && l7_pipe_rx_input == COM) begin
                
                next_state_l7 <= Q_TS;
                upcfgcap_cycle_l7 <= 1'b0;
            end else begin
                
                next_state_l7 <= ALGN;
                upcfgcap_cycle_l7 <= 1'b0;
            
            end
      Q_TS: if (l7_pipe_rx_input == PAD || l7_pipe_rx_input[8] == IS_D) begin
                
                next_state_l7 <= SYM2;
                upcfgcap_cycle_l7 <= 1'b0;
            
            end else begin
                
                next_state_l7 <= ALGN;
                upcfgcap_cycle_l7 <= 1'b0;
            
            end
      SYM2: begin 
                next_state_l7 <= SYM3;
                upcfgcap_cycle_l7 <= 1'b0;
            end
      
      SYM3: begin
                next_state_l7 <= SYM4;
                upcfgcap_cycle_l7 <= 1'b0;
            end
      
      SYM4: begin
                next_state_l7 <= ALGN;
                upcfgcap_cycle_l7 <= 1'b1;
            end
            
      default:  
            begin
                next_state_l7 <= ALGN;
                upcfgcap_cycle_l7 <= 1'b0;
            end
      
      endcase
            
   end
   
   always @(posedge clk) 
   begin : FSM_SYNC_L7
      if (!bit_reset_n)
         curr_state_l7 <= ALGN;
      else
         curr_state_l7 <= next_state_l7;
   end



//tie off for output port
assign upcfgcap_cycle = upcfgcap_cycle_l0;



   always @(posedge clk) 
   begin : REG_NEGOTIATED_LINK_WIDTH
         negotiated_link_width_d  <= negotiated_link_width;
   end
   

   // Double ACK masking
   // 1. Recognizing an ACK when it comes in on Lane 0
   //     a.  lanes 1 and 2 should be the same scrambled value (decrambled: 00 00)
   always @(l0_pipe_rx_input or pipe_rx_data_l1 or pipe_rx_data_l2 or negotiated_link_width_d[3] or trn_lnk_up_n_d) 
   begin : ACK_RECOGNITION_L0
      if ((l0_pipe_rx_input == SDP  &&           // DLLP
          pipe_rx_data_l1 == pipe_rx_data_l2 && // ACK
          negotiated_link_width_d[3] == 1'b1)     // 8-lane only 
	  && !trn_lnk_up_n_d)

           dllp_ack_l0 = 1'b1;
           
      else        
           dllp_ack_l0 = 1'b0;

   end

   // Double ACK masking
   // 1. Recognizing an ACK when it comes in on Lane 4
   //     a.  lanes 5 and 6 should be the same scrambled value (decrambled: 00 00)
   always @(l4_pipe_rx_input or pipe_rx_data_l5 or pipe_rx_data_l6 or negotiated_link_width_d[3] or trn_lnk_up_n_d) 
   begin : ACK_RECOGNITION_L4
      if ((l4_pipe_rx_input == SDP  &&           // DLLP
          pipe_rx_data_l5 == pipe_rx_data_l6 && // ACK
          negotiated_link_width_d[3] == 1'b1)     // 8-lane only 
	  && !trn_lnk_up_n_d)

           dllp_ack_l4 = 1'b1;

      else        
           dllp_ack_l4 = 1'b0;

   end


   // Double ACK masking(Lanes Reversed)
   // 1. Recognizing an ACK when it comes in on Lane 7
   //     a.  lanes 5 and 6 should be the same scrambled value (decrambled: 00 00)
   always @(l7_pipe_rx_input or pipe_rx_data_l5 or pipe_rx_data_l6 or negotiated_link_width_d[3] or trn_lnk_up_n_d) 
   begin : ACK_RECOGNITION_L7
      if ((l7_pipe_rx_input == SDP  &&           // DLLP
          pipe_rx_data_l5 == pipe_rx_data_l6 && // ACK
          negotiated_link_width_d[3] == 1'b1)     // 8-lane only 
	  && !trn_lnk_up_n_d)

           dllp_ack_l7_reverse = 1'b1;

      else        
           dllp_ack_l7_reverse = 1'b0;

   end

   // Double ACK masking(Lanes Reversed)
   // 1. Recognizing an ACK when it comes in on Lane 3
   //     a.  lanes 1 and 2 should be the same scrambled value (decrambled: 00 00)
   always @(l3_pipe_rx_input or pipe_rx_data_l1 or pipe_rx_data_l2 or negotiated_link_width_d[3] or trn_lnk_up_n_d) 
   begin : ACK_RECOGNITION_L3
      if ((l3_pipe_rx_input == SDP  &&           // DLLP
          pipe_rx_data_l1 == pipe_rx_data_l2 && // ACK
          negotiated_link_width_d[3] == 1'b1)     // 8-lane only 
	  && !trn_lnk_up_n_d)

           dllp_ack_l3_reverse = 1'b1;

      else        
           dllp_ack_l3_reverse = 1'b0;

   end




   always @(posedge clk)
   begin : REG_ACK
         dllp_ack_l0_r  <= dllp_ack_l0;
         dllp_ack_l4_r  <= dllp_ack_l4;
         dllp_ack_l4_rr <= dllp_ack_l4 && dllp_ack_l4_r;

         dllp_ack_l7_reverse_r  <= dllp_ack_l7_reverse;
         dllp_ack_l3_reverse_r  <= dllp_ack_l3_reverse;
         dllp_ack_l3_reverse_rr <= dllp_ack_l3_reverse && dllp_ack_l3_reverse_r;
   end
   

   // 3. Masking out the ACK that is redundant, in the same step where the up-configure fix takes place
   //    Register for better timing
   always @(posedge clk)
   begin : NEW_PIPE_OUT

     // Upconfigure fix     
     if(upcfgcap_cycle_l7 || upcfgcap_cycle_l6 || upcfgcap_cycle_l5 || upcfgcap_cycle_l4 ||
           upcfgcap_cycle_l3 || upcfgcap_cycle_l2 || upcfgcap_cycle_l1 || upcfgcap_cycle_l0) begin

     if (upcfgcap_cycle_l7 == 1'b1) 
        pipe_rx_data_l7_out <= 8'h02;

     if (upcfgcap_cycle_l6 == 1'b1)         
        pipe_rx_data_l6_out <= 8'h02;
        
     if (upcfgcap_cycle_l5 == 1'b1)         
        pipe_rx_data_l5_out <= 8'h02;
        
     if (upcfgcap_cycle_l4 == 1'b1)         
        pipe_rx_data_l4_out <= 8'h02;

     if (upcfgcap_cycle_l3 == 1'b1)          
        pipe_rx_data_l3_out <= 8'h02;
        
     if (upcfgcap_cycle_l2 == 1'b1)          
        pipe_rx_data_l2_out <= 8'h02;
        
     if (upcfgcap_cycle_l1 == 1'b1)          
        pipe_rx_data_l1_out <= 8'h02;
        
     if (upcfgcap_cycle_l0 == 1'b1)          
        pipe_rx_data_l0_out <= 8'h02;

        pipe_rx_data_k_out <= pipe_rx_data_k;
        pipe_rx_valid_out  <= pipe_rx_valid;
     
          // Double ACK fix (+ Lane Reversal)
     end else if ((dllp_ack_l0 == 1'b1 && dllp_ack_l0_r == 1'b1) ||
                  (dllp_ack_l7_reverse == 1'b1 && dllp_ack_l7_reverse_r == 1'b1)) begin
        pipe_rx_data_l7_out <= 8'b0;
        pipe_rx_data_l6_out <= 8'b0;
        pipe_rx_data_l5_out <= 8'b0;
        pipe_rx_data_l4_out <= 8'b0;
        pipe_rx_data_l3_out <= 8'b0;
        pipe_rx_data_l2_out <= 8'b0;
        pipe_rx_data_l1_out <= 8'b0;
        pipe_rx_data_l0_out <= 8'b0;

        pipe_rx_data_k_out <= 8'b0; // don't drive K char
        pipe_rx_valid_out  <= 8'b0; // indicate data not valid

     // Double ACK fix L4 (first clock) (+ Lane Reversal)
     end else if ((dllp_ack_l4 == 1'b1 && dllp_ack_l4_r == 1'b1) ||
                 (dllp_ack_l3_reverse_rr == 1'b1)) begin
        pipe_rx_data_l7_out <= 8'b0;
        pipe_rx_data_l6_out <= 8'b0;
        pipe_rx_data_l5_out <= 8'b0;
        pipe_rx_data_l4_out <= 8'b0;
        pipe_rx_data_l3_out <= pipe_rx_data_l3;
        pipe_rx_data_l2_out <= pipe_rx_data_l2;
        pipe_rx_data_l1_out <= pipe_rx_data_l1;
        pipe_rx_data_l0_out <= pipe_rx_data_l0;

        pipe_rx_data_k_out <= {4'b0, pipe_rx_data_k[3:0]}; // don't drive K char
        pipe_rx_valid_out  <= {4'b0, pipe_rx_valid[3:0]}; // indicate data not valid

     // Double ACK fix L4 (second clock) (+ Lane Reversal)
     end else if ((dllp_ack_l4_rr == 1'b1) ||
                 (dllp_ack_l3_reverse == 1'b1 && dllp_ack_l3_reverse_r == 1'b1)) begin
        pipe_rx_data_l7_out <= pipe_rx_data_l7;
        pipe_rx_data_l6_out <= pipe_rx_data_l6;
        pipe_rx_data_l5_out <= pipe_rx_data_l5;
        pipe_rx_data_l4_out <= pipe_rx_data_l4;
        pipe_rx_data_l3_out <= 8'b0;
        pipe_rx_data_l2_out <= 8'b0;
        pipe_rx_data_l1_out <= 8'b0;
        pipe_rx_data_l0_out <= 8'b0;

        pipe_rx_data_k_out <= {pipe_rx_data_k[7:4], 4'b0}; // don't drive K char
        pipe_rx_valid_out  <= {pipe_rx_valid[7:4],  4'b0}; // indicate data not valid

     // Normal
     end else begin
        pipe_rx_data_l7_out <= pipe_rx_data_l7;
        pipe_rx_data_l6_out <= pipe_rx_data_l6;
        pipe_rx_data_l5_out <= pipe_rx_data_l5;
        pipe_rx_data_l4_out <= pipe_rx_data_l4;
        pipe_rx_data_l3_out <= pipe_rx_data_l3;
        pipe_rx_data_l2_out <= pipe_rx_data_l2;
        pipe_rx_data_l1_out <= pipe_rx_data_l1;
        pipe_rx_data_l0_out <= pipe_rx_data_l0;
        
        pipe_rx_data_k_out <= pipe_rx_data_k;
        pipe_rx_valid_out  <= pipe_rx_valid;
        
     end     
   end

endmodule






