
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
// File       : pcie_reset_logic.v
//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
//
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor      : Xilinx
// \   \   \/     Version     : 1.1
//  \   \         Application : Generated by Xilinx PCI Express Wizard
//  /   /         Filename    : pcie_reset_logic.v
// /___/   /\     Module      : reset_logic 
// \   \  /  \
//  \___\/\___\
//
//------------------------------------------------------------------------------

module reset_logic
(
   L0DLUPDOWN,
   GSR,
   CRMCORECLK,
   USERCLK,
   L0LTSSMSTATE,
   L0STATSCFGTRANSMITTED,
   CRMDOHOTRESETN,
   CRMPWRSOFTRESETN,
   CRMMGMTRSTN,

   CRMNVRSTN,
   CRMMACRSTN,
   CRMLINKRSTN,
   CRMURSTN,
   CRMUSERCFGRSTN,
   
   user_master_reset_n,
   clock_ready
   
);

input L0DLUPDOWN;
input GSR;
input CRMCORECLK;
input USERCLK;
input [3:0] L0LTSSMSTATE;
input L0STATSCFGTRANSMITTED;
input CRMDOHOTRESETN;
input CRMPWRSOFTRESETN;

output CRMMGMTRSTN;
output CRMNVRSTN;
output CRMMACRSTN;
output CRMLINKRSTN;
output CRMURSTN;
output CRMUSERCFGRSTN;

input user_master_reset_n;
input clock_ready;

parameter G_RESETMODE = "FALSE";
parameter G_RESETSUBMODE = 1;
parameter G_USE_EXTRA_REG = 1;

// Common logic for all reset mode

wire fpga_logic_reset_n;
assign fpga_logic_reset_n = ~GSR && user_master_reset_n;

// L0DLUPDOWN[0] capture
reg dl_down_1, dl_down_2;
reg dl_down_reset_1_n, dl_down_reset_2_n;
reg dl_down_reset_n;
reg crm_pwr_soft_reset_n_aftersentcpl;
reg softreset_wait_for_cpl;
reg crmpwrsoftresetn_d;
reg l0statscfgtransmitted_d;
wire crmpwrsoftresetn_fell;

always @ (posedge CRMCORECLK, negedge fpga_logic_reset_n)
   if (!fpga_logic_reset_n) begin
        dl_down_1 <= 1'b1;
        dl_down_2 <= 1'b1;
   end else begin
        dl_down_1 <= L0DLUPDOWN;
        dl_down_2 <= dl_down_1;
   end

// Edge detect and pulse stretch to create dl_down_reset_n pulse
// The pulse can be further stretched for debugging purpose by adding
// more register stages.
always @ (posedge CRMCORECLK, negedge fpga_logic_reset_n)
   if (!fpga_logic_reset_n) begin
        dl_down_reset_1_n <= 1'b1;
        dl_down_reset_2_n <= 1'b1;
        dl_down_reset_n <= 1'b1;
   end else begin
        dl_down_reset_1_n <= ~(~dl_down_1 & dl_down_2);
        dl_down_reset_2_n <= dl_down_reset_1_n;
        dl_down_reset_n <= dl_down_reset_1_n && dl_down_reset_2_n;
   end


// This logic ensures that if we get a D3->D0 transition (which triggers
// soft_reset), then we will not reset until the Cpl is generated
// Wait for CRMPWRSOFTRESETN to assert to indicate this condition, and pulse
// CRMUSERCFGRSTN once the Cfg Cpl exits (L0STATSCFGTRANSMITTED). It is
// possible for L0STATSCFGTRANSMITTED to occur simultaneously or one cycle
// before CRMPWRSOFTRESETN asserts.
always @ (posedge USERCLK, negedge fpga_logic_reset_n)
   if      (!fpga_logic_reset_n)
        softreset_wait_for_cpl <= 1'b0;
   else if (crmpwrsoftresetn_fell && !L0STATSCFGTRANSMITTED && !l0statscfgtransmitted_d)
        softreset_wait_for_cpl <= 1'b1;
   else if (L0STATSCFGTRANSMITTED)
        softreset_wait_for_cpl <= 1'b0;

always @ (posedge USERCLK, negedge fpga_logic_reset_n)
   if      (!fpga_logic_reset_n) begin
        crm_pwr_soft_reset_n_aftersentcpl <= 1'b1;
        crmpwrsoftresetn_d                <= 1'b1;
        l0statscfgtransmitted_d           <= 1'b0;
   end else begin
        crm_pwr_soft_reset_n_aftersentcpl <= !((softreset_wait_for_cpl && L0STATSCFGTRANSMITTED) || 
                                               (!CRMPWRSOFTRESETN      && L0STATSCFGTRANSMITTED) ||
                                               (!CRMPWRSOFTRESETN      && l0statscfgtransmitted_d));
        crmpwrsoftresetn_d                <= CRMPWRSOFTRESETN;
        l0statscfgtransmitted_d           <= L0STATSCFGTRANSMITTED;
   end

assign crmpwrsoftresetn_fell = !CRMPWRSOFTRESETN && crmpwrsoftresetn_d;


// End common logic section

generate 
  if (G_RESETMODE == "TRUE") begin : resetmode_true
   // 6-domain reset mode (RESETMODE=TRUE)
   
     if (G_RESETSUBMODE == 0) begin : sub_0_mode_true
       // a. user_master_reset_n is used to drive CRMMGMTRSTN
       assign CRMMGMTRSTN = clock_ready && user_master_reset_n;
       assign CRMNVRSTN = 1'b1;
       assign CRMMACRSTN = 1'b1;
       assign CRMLINKRSTN = dl_down_reset_n && CRMDOHOTRESETN;
       assign CRMURSTN = dl_down_reset_n && CRMDOHOTRESETN;
       assign CRMUSERCFGRSTN = dl_down_reset_n && CRMDOHOTRESETN && crm_pwr_soft_reset_n_aftersentcpl;
     end
   
     else begin : sub_1_mode_true
       //b. user_master_reset_n is used but does not drive CRMMGMTRSTN
       assign CRMMGMTRSTN = clock_ready;
       assign CRMNVRSTN = user_master_reset_n;
       assign CRMMACRSTN = user_master_reset_n;
       assign CRMLINKRSTN = user_master_reset_n && dl_down_reset_n && CRMDOHOTRESETN;
       assign CRMURSTN = user_master_reset_n && dl_down_reset_n && CRMDOHOTRESETN;
       assign CRMUSERCFGRSTN = user_master_reset_n && dl_down_reset_n && CRMDOHOTRESETN && crm_pwr_soft_reset_n_aftersentcpl;
     end
   
   // End 6-domain reset mode logic
  end
endgenerate


generate 
  if (G_RESETMODE == "FALSE") begin : resetmode_false
    // 4-domain hierarchical reset mode (RESETMODE=FALSE)
    // This mode requires decoding the L0LTSSMSTATE outputs
    // from the PCIe block to detect LTSSM transition from Disabled
    // (1011), Loopback (1001) or Hot Reset (1010) to Detect (0001).
    wire ltssm_linkdown_hot_reset_n;
    reg ltssm_dl_down_last_state;
    reg [3:0] ltssm_capture;
    reg crmpwrsoftresetn_capture;
    reg ltssm_linkdown_hot_reset_reg_n;
    
    // Use with G_USE_EXTRA_REG == 1 for better timing
    always @ (posedge CRMCORECLK) begin
       ltssm_capture <= L0LTSSMSTATE;
       //crmpwrsoftresetn_capture <= CRMPWRSOFTRESETN;
       crmpwrsoftresetn_capture <= crm_pwr_soft_reset_n_aftersentcpl;
       ltssm_linkdown_hot_reset_reg_n <= ltssm_linkdown_hot_reset_n;
    end
    
    always @ (posedge CRMCORECLK, negedge fpga_logic_reset_n) begin
       if (G_USE_EXTRA_REG == 1) begin
          if (!fpga_logic_reset_n) begin
               ltssm_dl_down_last_state <= 1'b0;
          end else if ((ltssm_capture == 4'b1010) || (ltssm_capture == 4'b1001) || (ltssm_capture == 4'b1011) ||
                       (ltssm_capture == 4'b1100) || (ltssm_capture == 4'b0011)) begin
               ltssm_dl_down_last_state <= 1'b1;
          end else begin
               ltssm_dl_down_last_state <= 1'b0;
          end
       end else begin
          if (!fpga_logic_reset_n) begin
               ltssm_dl_down_last_state <= 1'b0;
          end else if ((L0LTSSMSTATE == 4'b1010) || (L0LTSSMSTATE == 4'b1001) || (L0LTSSMSTATE == 4'b1011) ||
                       (L0LTSSMSTATE == 4'b1100) || (L0LTSSMSTATE == 4'b0011)) begin
               ltssm_dl_down_last_state <= 1'b1;
          end else begin
               ltssm_dl_down_last_state <= 1'b0;
          end
       end
    end
    
    assign ltssm_linkdown_hot_reset_n = (G_USE_EXTRA_REG == 1) ? 
         ~(ltssm_dl_down_last_state && (ltssm_capture[3:1] == 3'b000)) :
         ~(ltssm_dl_down_last_state && (L0LTSSMSTATE[3:1] == 3'b000));
    
      if (G_RESETSUBMODE == 0) begin : sub_0_mode_false
         // a. user_master_reset_n is used to drive CRMMGMTRSTN
         assign CRMMGMTRSTN = clock_ready && user_master_reset_n;
         assign CRMNVRSTN = 1'b1;
         assign CRMURSTN = (G_USE_EXTRA_REG == 1) ? ltssm_linkdown_hot_reset_reg_n : ltssm_linkdown_hot_reset_n;
         assign CRMUSERCFGRSTN = (G_USE_EXTRA_REG == 1) ? crmpwrsoftresetn_capture : crm_pwr_soft_reset_n_aftersentcpl;
         assign CRMMACRSTN = 1'b1;  // not used, just avoiding 'z' in simulation
         assign CRMLINKRSTN = 1'b1; // not used, just avoiding 'z' in simulation
      end
    
      else begin : sub_1_mode_false
         // b. user_master_reset_n is used but does not drive CRMMGMTRSTN
         assign CRMMGMTRSTN = clock_ready;
         assign CRMNVRSTN = user_master_reset_n;
         assign CRMURSTN = (G_USE_EXTRA_REG == 1) ? ltssm_linkdown_hot_reset_reg_n : ltssm_linkdown_hot_reset_n;
         assign CRMUSERCFGRSTN = (G_USE_EXTRA_REG == 1) ? crmpwrsoftresetn_capture : crm_pwr_soft_reset_n_aftersentcpl;
         assign CRMMACRSTN = 1'b1;  // not used, just avoiding 'z' in simulation
         assign CRMLINKRSTN = 1'b1; // not used, just avoiding 'z' in simulation
      end
    
    // End 4-domain hierarchical reset mode logic
  end
endgenerate

endmodule
