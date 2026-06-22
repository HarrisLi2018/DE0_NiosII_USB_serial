// --------------------------------------------------------------------
//
// Major Functions:	DE0 TOP
//
// --------------------------------------------------------------------
//
// Revision History :
// --------------------------------------------------------------------
//   Ver  :| Author            :| Mod. Date :| Changes Made:

// --------------------------------------------------------------------

module usb_uart_top (
            iClk50M,  // 50Mhz clock
    
            iRst_n,   // While iRst_n is low (active low), the module shall be reset

    // ---- to/from Application ------------------------------------
            app_clk_i,
            out_data_o,
            out_valid_o,
    // While out_valid_o is high, the out_data_o shall be valid and both
    //   out_valid_o and out_data_o shall not change until consumed.
            out_ready_i,
    // When both out_valid_o and out_ready_i are high, the out_data_o shall
    //   be consumed.
            in_data_i,
            in_valid_i,
    // While in_valid_i is high, in_data_i shall be valid.
            in_ready_o,
    // When both in_ready_o and in_valid_i are high, in_data_i shall
    //   be consumed.
            frame_o,
    // frame_o shall be last recognized USB frame number sent by USB host.
            configured_o,
    // While USB_CDC is in configured state, configured_o shall be high.

    // ---- to USB bus physical transmitters/receivers --------------
            dp_pu_o,        /* DP pull */
            tx_en_o,        /* tri-state switch */
            dp_tx_o,        /* D+ out */
            dn_tx_o,        /* D- out */
            dp_rx_i,        /* D+ in */
            dn_rx_i         /* D- in */
    );

input         iClk50M;
// clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
input         iRst_n;
// While rstn_i is low (active low), the module shall be reset

// ---- to/from Application ------------------------------------
input         app_clk_i;
output [7:0]  out_data_o;
output        out_valid_o;
// While out_valid_o is high, the out_data_o shall be valid and both
//   out_valid_o and out_data_o shall not change until consumed.
input         out_ready_i;
// When both out_valid_o and out_ready_i are high, the out_data_o shall
//   be consumed.
input [7:0]   in_data_i;
input         in_valid_i;
// While in_valid_i is high, in_data_i shall be valid.
output        in_ready_o;
// When both in_ready_o and in_valid_i are high, in_data_i shall
//   be consumed.
output [10:0] frame_o;
// frame_o shall be last recognized USB frame number sent by USB host.
output        configured_o;
// While USB_CDC is in configured state, configured_o shall be high.

// ---- to USB bus physical transmitters/receivers --------------
output        dp_pu_o;        /* DP pull */
output        tx_en_o;        /* tri-state switch */
output        dp_tx_o;        /* D+ out */
output        dn_tx_o;        /* D- out */
input         dp_rx_i;        /* D+ in */
input         dn_rx_i;        /* D- in */

// --------------------------------------------------------------------
//
// Major Functions:	DE0 TOP
//
// --------------------------------------------------------------------
//
// Revision History :
// --------------------------------------------------------------------
//   Ver  :| Author            :| Mod. Date :| Changes Made:

// --------------------------------------------------------------------

wire       clk48mhz, clk96mhz, clk12mhz;
wire       clk_locked;

usb_pll altpll_i(
    .inclk0 (iClk50M),
    .c0     (clk48mhz),
    .c1     (clk96mhz),
    .c2     (clk12mhz),
    .locked (clk_locked)
    );
wire [7:0] USB_RXDATA;
wire       USB_RXDVAL;
wire       USB_IN_READY;
wire       USB_CONFIGURED;
wire       usb_rstn;

assign usb_rstn = iRst_n;
//assign LEDG[0] = clk_locked;
//assign LEDG[1] = USB_CONFIGURED;
//assign LEDG[9:2] = 8'h00;

usb_cdc
  #( .VENDORID              (16'h1234),
     .PRODUCTID             (16'h5678),
     .IN_BULK_MAXPACKETSIZE ('d64),
     .OUT_BULK_MAXPACKETSIZE('d64),
     .BIT_SAMPLES           ('d4),
     .USE_APP_CLK           (0),
     .APP_CLK_RATIO         ('d4))
   usb_cdc (
             .clk_i(clk48mhz),
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
             .rstn_i(iRst_n),
    // While rstn_i is low (active low), the module shall be reset

    // ---- to/from Application ------------------------------------
             .app_clk_i(1'b0),
             .out_data_o    (out_data_o),
             .out_valid_o   (out_valid_o), // While out_valid_o is high, the out_data_o shall be valid and both
                                           //   out_valid_o and out_data_o shall not change until consumed.
             .out_ready_i   (out_ready_i),
    // When both out_valid_o and out_ready_i are high, the out_data_o shall be consumed.
             .in_data_i     (in_data_i),
             .in_valid_i    (in_valid_i),
    // While in_valid_i is high, in_data_i shall be valid.
             .in_ready_o    (in_ready_o),    // When both in_ready_o and in_valid_i are high, in_data_i shall be consumed.
             .frame_o       (),    // frame_o shall be last recognized USB frame number sent by USB host.
             .configured_o(USB_CONFIGURED),  // While USB_CDC is in configured state, configured_o shall be high.

    // ---- to USB bus physical transmitters/receivers --------------
            .dp_pu_o(dp_pu_o),  /* DP pull */
            .tx_en_o(tx_en_o),      /* tri-state switch */
            .dp_tx_o(dp_tx_o),      /* D+ out */
            .dn_tx_o(dn_tx_o),      /* D- out */
            .dp_rx_i(dp_rx_i),  /* D+ in */
            .dn_rx_i(dn_rx_i)   /* D- in */
    );
    
endmodule
