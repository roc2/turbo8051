//////////////////////////////////////////////////////////////////////
////                                                              ////
////  Tubo 8051 cores MAC Interface Module                        ////
////                                                              ////
////  This file is part of the Turbo 8051 cores project           ////
////  http://www.opencores.org/cores/turbo8051/                   ////
////                                                              ////
////  Description                                                 ////
////  Turbo 8051 definitions.                                     ////
////                                                              ////
////  To Do:                                                      ////
////    nothing                                                   ////
////                                                              ////
////  Author(s):                                                  ////
////      - Dinesh Annayya, dinesha@opencores.org                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

// ------------------------------------------------------------------------
// Description      : 
//   This module instantiates the MAC block and the FIFO interface
//
// ------------------------------------------------------------------------
module  g_mac_top (
                    scan_mode, 
                    s_reset_n, 
                    tx_reset_n,
                    rx_reset_n,
                    reset_mdio_clk_n,
                    app_reset_n,

                    app_clk,
                    app_send_pause_i,
                    app_send_pause_active_o,
                    app_send_jam_i,

                    // Application RX FIFO Interface
                    app_txfifo_wren_i,
                    app_txfifo_wrdata_i,
                    app_txfifo_full_o,
                    app_txfifo_afull_o,
                    app_txfifo_space_o,

                    // Application TX FIFO Interface
                    app_rxfifo_rden_i,
                    app_rxfifo_empty_o,
                    app_rxfifo_aempty_o,
                    app_rxfifo_cnt_o,
                    app_rxfifo_rdata_o,

                    // Conntrol Bus Sync with Application Clock
                    reg_cs,
                    reg_wr,
                    reg_addr,
                    reg_wdata,
                    reg_be,

                     // Outputs
                    reg_rdata,
                    reg_ack,


                    // Phy Signals 

                    // Line Side Interface TX Path
                    phy_tx_en,
                    phy_tx_er,
                    phy_txd,
                    phy_tx_clk,

                    // Line Side Interface RX Path
                    phy_rx_clk,
                    phy_rx_er,
                    phy_rx_dv,
                    phy_rxd,
                    phy_crs,

                    //MDIO interface
                    mdio_clk,
                    mdio_in,
                    mdio_out_en,
                    mdio_out
       );

parameter W  = 8'd9;
parameter DP = 8'd32;
parameter AW = (DP == 2)   ? 1 : 
	       (DP == 4)   ? 2 :
               (DP == 8)   ? 3 :
               (DP == 16)  ? 4 :
               (DP == 32)  ? 5 :
               (DP == 64)  ? 6 :
               (DP == 128) ? 7 :
               (DP == 256) ? 8 : 0;


//-----------------------------------------------------------------------
// INPUT/OUTPUT DECLARATIONS
//-----------------------------------------------------------------------
input                    scan_mode; 
input                    s_reset_n; 
input                    tx_reset_n;
input                    rx_reset_n;
input                    reset_mdio_clk_n;
input                    app_reset_n;

//-----------------------------------------------------------------------
// Application Clock Related Declaration
//-----------------------------------------------------------------------
input                    app_clk;
input                    app_send_pause_i;
output                   app_send_pause_active_o;
input                    app_send_jam_i;


// Application RX FIFO Interface
input                    app_txfifo_wren_i;
input  [8:0]             app_txfifo_wrdata_i;
output                   app_txfifo_full_o;
output                   app_txfifo_afull_o;
output [AW:0]            app_txfifo_space_o;

// Application TX FIFO Interface
input                    app_rxfifo_rden_i;
output                   app_rxfifo_empty_o;
output                   app_rxfifo_aempty_o;
output [AW:0]            app_rxfifo_cnt_o;
output [8:0]             app_rxfifo_rdata_o;

// Conntrol Bus Sync with Application Clock
//---------------------------------
// Reg Bus Interface Signal
//---------------------------------
input             reg_cs         ;
input             reg_wr         ;
input [3:0]       reg_addr       ;
input [31:0]      reg_wdata      ;
input [3:0]       reg_be         ;
   
   // Outputs
output [31:0]     reg_rdata      ;
output            reg_ack        ;

//-----------------------------------------------------------------------
// Line-Tx Signal
//-----------------------------------------------------------------------
output            phy_tx_en;
output            phy_tx_er;
output [7:0]      phy_txd;
input	          phy_tx_clk;

//-----------------------------------------------------------------------
// Line-Rx Signal
//-----------------------------------------------------------------------
input	          phy_rx_clk;
input	          phy_rx_er;
input	          phy_rx_dv;
input [7:0]       phy_rxd;
input	          phy_crs;


//-----------------------------------------------------------------------
// MDIO Signal
//-----------------------------------------------------------------------
  input	       mdio_clk;
  input	       mdio_in;
  output       mdio_out_en;
  output       mdio_out;

//---------------------
// RX FIFO Interface Signal
  wire         clr_rx_error_from_rx_fsm_o;
  wire         rx_fifo_full_i;
  wire         rx_fifo_wr_o;
  wire  [8:0]  rx_fifo_data_o;
  wire         rx_commit_wr_o;
  wire         rx_commit_write_done_o;   
  wire         rx_rewind_wr_o;
  wire         rx_fifo_error = 1'b0;

//-----------------------------------------------------------------------
// TX-Clock Domain Status Signal
//-----------------------------------------------------------------------
  wire        tx_commit_read;
  wire        tx_fifo_rd;

  wire [8:0]  tx_fifo_data;
  wire        tx_fifo_empty;
  wire        tx_fifo_rdy;
  wire [AW:0]  tx_fifo_aval;

g_mac_core u_mac_core  (
                    .scan_mode               (scan_mode), 
                    .s_reset_n               (s_reset_n) , 
                    .tx_reset_n              (tx_reset_n) ,
                    .rx_reset_n              (rx_reset_n) ,
                    .reset_mdio_clk_n        (reset_mdio_clk_n) ,
                    .app_reset_n             (app_reset_n) ,

                 // Reg Bus Interface Signal
                    . reg_cs                 (reg_cs),
                    . reg_wr                 (reg_wr),
                    . reg_addr               (reg_addr),
                    . reg_wdata              (reg_wdata),
                    . reg_be                 (reg_be),

                     // Outputs
                     . reg_rdata             (reg_rdata),
                     . reg_ack               (reg_ack),

                    .app_clk                 (app_clk) ,
                    .app_send_pause_i        (app_send_pause_i) ,
                    .app_send_pause_active_o (app_send_pause_active_o) ,
                    .app_send_jam_i          (app_send_jam_i) ,

                    // Conntrol Bus Sync with Application Clock



                  // RX FIFO Interface Signal
                    .rx_fifo_full_i          (rx_fifo_full_i) ,
                    .rx_fifo_wr_o            (rx_fifo_wr_o) ,
                    .rx_fifo_data_o          (rx_fifo_data_o) ,
                    .rx_commit_wr_o          (rx_commit_wr_o) ,
                    .rx_rewind_wr_o          (rx_rewind_wr_o) ,
                    .rx_commit_write_done_o  (rx_commit_write_done_o) ,
                    .clr_rx_error_from_rx_fsm_o(clr_rx_error_from_rx_fsm_o) ,
                    .rx_fifo_error_i         (rx_fifo_error) , 

                  // TX FIFO Interface Signal
                    .tx_fifo_data_i          (tx_fifo_data) ,
                    .tx_fifo_empty_i         (tx_fifo_empty) ,
                    .tx_fifo_rdy_i           (tx_fifo_rdy) , // See to connect to config
                    .tx_fifo_rd_o            (tx_fifo_rd) ,
                    .tx_commit_read_o        (tx_commit_read) ,

                    // Phy Signals 

                    // Line Side Interface TX Path
                    .phy_tx_en               (phy_tx_en) ,
                    .phy_tx_er               (phy_tx_er) ,
                    .phy_txd                 (phy_txd) ,
                    .phy_tx_clk              (phy_tx_clk) ,

                    // Line Side Interface RX Path
                    .phy_rx_clk              (phy_rx_clk) ,
                    .phy_rx_er               (phy_rx_er) ,
                    .phy_rx_dv               (phy_rx_dv) ,
                    .phy_rxd                 (phy_rxd) ,
                    .phy_crs                 (phy_crs) ,

                    //MDIO interface
                    .mdio_clk                (mdio_clk) ,
                    .mdio_in                 (mdio_in) ,
                    .mdio_out_en             (mdio_out_en) ,
                    .mdio_out                (mdio_out)
       );

assign tx_fifo_rdy = (tx_fifo_aval > 8) ; // Dinesh-A Change it to config

async_fifo #(W,DP,0,0) u_mac_txfifo  (
                   .wr_clk                   (app_clk),
                   .wr_reset_n               (app_reset_n),
                   .wr_en                    (app_txfifo_wren_i),
                   .wr_data                  (app_txfifo_wrdata_i),
                   .full                     (app_txfifo_full_o), // sync'ed to wr_clk
                   .afull                    (app_txfifo_afull_o), // sync'ed to wr_clk
                   .wr_total_free_space      (app_txfifo_space_o),

                   .rd_clk                   (phy_tx_clk),
                   .rd_reset_n               (tx_reset_n),
                   .rd_en                    (tx_fifo_rd),
                   .empty                    (tx_fifo_empty),  // sync'ed to rd_clk
                   .aempty                   (tx_fifo_aempty), // sync'ed to rd_clk
                   .rd_total_aval            (tx_fifo_aval),
                   .rd_data                  (tx_fifo_data)
                   );

async_fifo #(W,DP,0,0) u_mac_rxfifo (                  
                   .wr_clk                   (phy_rx_clk),
                   .wr_reset_n               (rx_reset_n),
                   .wr_en                    (rx_fifo_wr_o),
                   .wr_data                  (rx_fifo_data_o),
                   .full                     (rx_fifo_full_i), // sync'ed to wr_clk
                   .afull                    (rx_fifo_afull_i), // sync'ed to wr_clk
                   .wr_total_free_space      (),

                   .rd_clk                   (app_clk),
                   .rd_reset_n               (app_reset_n),
                   .rd_en                    (app_rxfifo_rden_i),
                   .empty                    (app_rxfifo_empty_o),  // sync'ed to rd_clk
                   .aempty                   (app_rxfifo_aempty_o), // sync'ed to rd_clk
                   .rd_total_aval            (app_rxfifo_cnt_o),
                   .rd_data                  (app_rxfifo_rdata_o)
                   );



endmodule 

