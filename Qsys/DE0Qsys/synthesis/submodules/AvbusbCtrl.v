
// --------------------------------------------------------------------
// Copyright (c) 2011 by TKU ICLAB. 
// --------------------------------------------------------------------
//                     email: lishyhan@gms.tku.edu.tw
// --------------------------------------------------------------------
//
// Major Functions: AvbusbCtrl.v
//
// --------------------------------------------------------------------
// Notes:
//   1. This block is an Avalon-MM slave that bridges the Nios II system to
//      an embedded USB CDC core through two asynchronous FIFOs.
//   2. Avalon-MM register map:
//      address 0: DATA   write pushes one byte to USB TX FIFO,
//                        read pops one byte from USB RX FIFO.
//      address 1: STATUS see status bit definitions below.
//      address 2: CTRL   interrupt enable/control register.
//      address 3: RX_CNT number of bytes currently buffered for Avalon reads.
//   3. The Avalon control path is fully registered. Read data and FIFO
//      push/pop strobes update on csi_clockreset_clk.
//   4. DATA writes use avs_s1_waitrequest for back-pressure when the USB TX
//      FIFO is not ready. This prevents false write errors caused by transient
//      FIFO full flags across the clock-domain boundary.
//   5. avs_s1_byteenable[0] gates DATA writes. CTRL honors all byte lanes.
// -----------------------------------------------------------------------------
// Revision History :
// --------------------------------------------------------------------
//  Ver  :| Author            :| Mod. Date  :| Changes Made:
//   1.0 :| Shih-An Li        :| 2026/06/12 :| initial 
// --------------------------------------------------------------------

`default_nettype none
module AvbusbCtrl(
  // Avalon clock and reset interface.
            csi_clockreset_clk,
            csi_clockreset_reset_n,

  // Avalon-MM slave interface used by the Nios II CPU.
            avs_s1_write,
            avs_s1_writedata,
            avs_s1_read,
            avs_s1_readdata,
            avs_s1_address,
            avs_s1_waitrequest,
            avs_s1_byteenable,
            
            avs_s1_irq,
            
            /* Exported USB CDC clock and PHY interface. */
            avs_export_clk50_i,
            avs_export_dp_pu_o,                /* DP pull */
            avs_export_tx_en_o,                /* tri-state switch */
            avs_export_dp_tx_o,                /* D+ out */
            avs_export_dn_tx_o,                /* D- out */
            avs_export_dp_rx_i,                /* D+ in */
            avs_export_dn_rx_i                 /* D- in */
          
          );
//===========================================================================
// PARAMETER declarations
//===========================================================================

parameter        fifodepth=1024;
parameter        fifowidth=8;

//===========================================================================
// PORT declarations
//===========================================================================

  // Avalon clock/reset interface signals.
input               csi_clockreset_clk;
input               csi_clockreset_reset_n;     /* active-low Avalon reset */

  // Avalon-MM slave port.
input               avs_s1_write;               /* Avalon write request */
input       [31:0]  avs_s1_writedata;           /* Avalon write data */
input               avs_s1_read;                /* Avalon read request */
output  reg [31:0]  avs_s1_readdata;            /* registered Avalon read data */
input       [1:0]   avs_s1_address;             /* register index: DATA/STATUS/CTRL/RX_CNT */
output              avs_s1_waitrequest;         /* stalls DATA writes while TX FIFO is busy */
input       [3:0]   avs_s1_byteenable;          /* byte lane enable; DATA uses byte 0 */
output              avs_s1_irq;                 /* combined RX/TX/error interrupt */


  // Exported USB PHY and reference-clock pins.
input               avs_export_clk50_i;         /* 50 MHz reference clock for USB PLL */
output              avs_export_dp_pu_o;         /* USB D+ pull-up control */
output              avs_export_tx_en_o;         /* USB D+/D- output-enable control */
output              avs_export_dp_tx_o;         /* USB D+ transmit value */
output              avs_export_dn_tx_o;         /* USB D- transmit value */
input               avs_export_dp_rx_i;         /* USB D+ receive value */
input               avs_export_dn_rx_i;         /* USB D- receive value */
  
//=============================================================================
// REG/WIRE declarations
//=============================================================================
// Avalon register set and error latches.
reg         [31:0]  avl_ctrl_reg;               /* CTRL register: interrupt enables */
reg         [31:0]  avl_status_reg;             /* STATUS register snapshot */
reg         [31:0]  avl_rx_count_reg;           /* RX_CNT register snapshot */
reg                 fifo_error_flag_clear_reg;  /* one-cycle clear for FIFO error latches */
reg                 avl_data_write_error_latch; /* DATA write accepted while TX path is invalid */
reg                 avl_data_read_error_latch;  /* DATA read requested while RX FIFO is empty */

// Avalon-to-USB TX FIFO signals. Write side is Avalon clock, read side is USB clock.
wire                avl_to_usb_fifo_empty;      /* TX FIFO empty, observed on read side */
wire                avl_to_usb_fifo_full;       /* TX FIFO full, observed on write side */
wire        [9:0]   avl_to_usb_fifo_usedw;      /* TX FIFO used words in Avalon write domain */
wire        [7:0]   avl_to_usb_fifo_usedw_status;
wire                avl_to_usb_fifo_overflow_latch;
wire                avl_to_usb_fifo_underflow_latch;
reg                 avl_to_usb_fifo_wrreq_reg;  /* one-cycle Avalon write strobe into TX FIFO */
reg         [7:0]   avl_to_usb_fifo_wdata_reg;  /* byte written by Avalon DATA writes */

// USB-to-Avalon RX FIFO signals. Write side is USB clock, read side is Avalon clock.
wire                usb_to_avl_fifo_empty;      /* RX FIFO empty, observed on Avalon read side */
wire                usb_to_avl_fifo_full;       /* RX FIFO full, observed on USB write side */
wire        [9:0]   usb_to_avl_fifo_usedw;      /* RX FIFO used words in Avalon read domain */
wire        [7:0]   usb_to_avl_fifo_usedw_status;
wire                usb_to_avl_fifo_overflow_latch;
wire                usb_to_avl_fifo_underflow_latch;
reg                 usb_to_avl_fifo_rdreq_reg;  /* one-cycle Avalon read strobe from RX FIFO */
wire        [7:0]   usb_to_avl_fifo_rdata;      /* byte returned from RX FIFO */

// USB CDC streaming interface.
wire        [7:0]   usb_cdc_rx_data;            /* USB OUT byte from host */
wire                usb_cdc_rx_valid;           /* USB OUT byte is valid */
wire                usb_cdc_rx_ready;           /* RX FIFO has room for USB OUT byte */
wire        [7:0]   usb_cdc_tx_data;            /* USB IN byte sent to host */
wire                usb_cdc_tx_valid;           /* TX FIFO has a byte for USB IN endpoint */
wire                usb_cdc_tx_ready;           /* USB CDC core consumed one TX byte */
wire                usb_cdc_configured;         /* raw configured flag in USB clock domain */

// USB PLL and reset-control signals.
wire                clk48mhz;                   /* USB full-speed sample clock */
wire                clk96mhz;                   /* currently unused PLL output */
wire                clk12mhz;                   /* currently unused PLL output */
wire                clk_locked;                 /* raw PLL lock flag */
wire                usb_core_reset_n;           /* USB core reset, released after PLL lock */
wire                usb_fifo_aclr;              /* asynchronous FIFO clear */

// Avalon-domain ready/status helpers.
wire                avl_usb_ready;              /* PLL lock has been stable long enough */
wire                avl_to_usb_write_ready;     /* DATA write can be accepted now */
wire                avl_data_write_waitrequest; /* combinational Avalon DATA write stall */
wire                avl_data_read_request;      /* Avalon is reading DATA register */
wire                avl_data_read_waitrequest;  /* one-cycle DATA read latency */
wire                avl_to_usb_fifo_empty_status;
wire                avl_to_usb_fifo_full_status;
wire                usb_to_avl_fifo_empty_status;
wire                usb_to_avl_fifo_full_status;
wire                usb_cdc_configured_status;

// Synchronizers for status bits that cross into the Avalon clock domain.
reg         [1:0]   avl_clk_locked_sync;
reg         [1:0]   usb_cdc_configured_sync;
reg         [1:0]   avl_to_usb_fifo_empty_sync;
reg         [1:0]   usb_to_avl_fifo_full_sync;
reg         [7:0]   avl_usb_ready_delay_cnt;    /* warm-up delay after PLL lock */
reg                 avl_data_read_pending;      /* DATA read data has been staged */

//=============================================================================
// Structural coding
//=============================================================================
// STATUS register:
//   bit 0      RX FIFO empty (USB -> Avalon)
//   bit 1      TX FIFO empty (Avalon -> USB)
//   bit 2      TX FIFO full (Avalon -> USB)
//   bit 3      RX FIFO full (USB -> Avalon)
//   bits 7:4   Reserved
//   bits 15:8  RX FIFO used words
//   bits 23:16 TX FIFO used words
//   bit 24     RX IRQ pending (RX FIFO has data and RX IRQ is enabled)
//   bit 25     TX IRQ pending (TX FIFO has space and TX IRQ is enabled)
//   bit 26     DATA write error latch: Avalon write while TX FIFO is full
//   bit 27     DATA read error latch: Avalon read while RX FIFO is empty
//   bit 28     Error flag: OR of all error latch flags, include overflow, underflow
//   bit 29     USB CDC configured
//   bits 31:30 Reserved
//   write       Clear error latch flags

// Control register:
//   bit 0      RX interrupt enable: assert irq when USB->Avalon FIFO has data.
//   bit 1      TX interrupt enable: assert irq when Avalon->USB FIFO has space.
//   bit 2      Error interrupt enable: assert irq when any error flag is set.
/* Avalon register and FIFO-strobe process. */

wire usb_rx_irq_enable;
wire usb_tx_irq_enable;
wire usb_error_irq_enable;
wire usb_rx_irq_pending;
wire usb_tx_irq_pending;
wire usb_error_irq_pending;
wire avl_any_error_latch;
wire avl_write_accept;
wire avl_read_accept;

// Decode interrupt-enable bits from CTRL.
assign usb_rx_irq_enable  = avl_ctrl_reg[0];
assign usb_tx_irq_enable  = avl_ctrl_reg[1];
assign usb_error_irq_enable = avl_ctrl_reg[2];

// Generate level-sensitive interrupt sources in the Avalon clock domain.
assign usb_rx_irq_pending = usb_rx_irq_enable & avl_usb_ready & !usb_to_avl_fifo_empty;
assign usb_tx_irq_pending = usb_tx_irq_enable & avl_to_usb_write_ready;
assign avl_any_error_latch = avl_data_write_error_latch |
                             avl_data_read_error_latch |
                             avl_to_usb_fifo_overflow_latch |
                             avl_to_usb_fifo_underflow_latch |
                             usb_to_avl_fifo_overflow_latch |
                             usb_to_avl_fifo_underflow_latch;
assign usb_error_irq_pending = usb_error_irq_enable & avl_any_error_latch;
assign avs_s1_irq = usb_rx_irq_pending | usb_tx_irq_pending | usb_error_irq_pending;

// Back-pressure DATA writes, and add one wait cycle for DATA reads so the
// registered readdata bus returns the byte popped from the RX FIFO.
assign avl_data_write_waitrequest = avs_s1_write & !avs_s1_read &
                                    (avs_s1_address == 2'd0) &
                                    avs_s1_byteenable[0] &
                                    !avl_to_usb_write_ready;
assign avl_data_read_request = avs_s1_read & !avs_s1_write & (avs_s1_address == 2'd0);
assign avl_data_read_waitrequest = avl_data_read_request & !avl_data_read_pending;
assign avs_s1_waitrequest = avl_data_write_waitrequest | avl_data_read_waitrequest;
assign avl_write_accept = avs_s1_write & !avs_s1_waitrequest;
assign avl_read_accept = avs_s1_read & !avs_s1_waitrequest;

// Hold USB logic and FIFOs in reset until the local USB PLL is locked.
assign usb_core_reset_n = csi_clockreset_reset_n & clk_locked;
assign usb_fifo_aclr = !usb_core_reset_n;

// Publish conservative STATUS values until the USB/FIFO path is stable.
assign avl_usb_ready = avl_usb_ready_delay_cnt[7];
assign avl_to_usb_write_ready = avl_usb_ready & !avl_to_usb_fifo_full;
assign avl_to_usb_fifo_empty_status = !avl_usb_ready ? 1'b1 : avl_to_usb_fifo_empty_sync[1];
assign avl_to_usb_fifo_full_status  = !avl_usb_ready ? 1'b1 : avl_to_usb_fifo_full;
assign usb_to_avl_fifo_empty_status = !avl_usb_ready ? 1'b1 : usb_to_avl_fifo_empty;
assign usb_to_avl_fifo_full_status  = !avl_usb_ready ? 1'b0 : usb_to_avl_fifo_full_sync[1];
assign usb_cdc_configured_status = avl_usb_ready & usb_cdc_configured_sync[1];
assign avl_to_usb_fifo_usedw_status = (avl_to_usb_fifo_usedw[9:8] != 2'b00) ? 8'hff : avl_to_usb_fifo_usedw[7:0];
assign usb_to_avl_fifo_usedw_status = (usb_to_avl_fifo_usedw[9:8] != 2'b00) ? 8'hff : usb_to_avl_fifo_usedw[7:0];

always@(posedge csi_clockreset_clk or negedge csi_clockreset_reset_n) begin
    if (!csi_clockreset_reset_n) begin
        avs_s1_readdata    <= 32'd0;
        avl_ctrl_reg              <= 32'd0;
        avl_status_reg            <= 32'd0;
        avl_rx_count_reg          <= 32'd0;
        avl_to_usb_fifo_wrreq_reg <= 1'b0;
        usb_to_avl_fifo_rdreq_reg <= 1'b0;
        avl_to_usb_fifo_wdata_reg <= 8'd0;
        fifo_error_flag_clear_reg <= 1'b0;
        avl_data_write_error_latch <= 1'b0;
        avl_data_read_error_latch  <= 1'b0;
        avl_clk_locked_sync        <= 2'b00;
        usb_cdc_configured_sync    <= 2'b00;
        avl_to_usb_fifo_empty_sync <= 2'b11;
        usb_to_avl_fifo_full_sync  <= 2'b00;
        avl_usb_ready_delay_cnt    <= 8'd0;
        avl_data_read_pending      <= 1'b0;
    end
    else begin
        // FIFO request and clear strobes are pulses; default low each Avalon cycle.
        avl_to_usb_fifo_wrreq_reg <= 1'b0;
        usb_to_avl_fifo_rdreq_reg <= 1'b0;
        fifo_error_flag_clear_reg <= 1'b0;

        if (!avs_s1_read) begin
            avl_data_read_pending <= 1'b0;
        end

        // Synchronize USB-domain status bits before software reads them.
        avl_clk_locked_sync        <= {avl_clk_locked_sync[0], clk_locked};
        usb_cdc_configured_sync    <= {usb_cdc_configured_sync[0], usb_cdc_configured};
        avl_to_usb_fifo_empty_sync <= {avl_to_usb_fifo_empty_sync[0], avl_to_usb_fifo_empty};
        usb_to_avl_fifo_full_sync  <= {usb_to_avl_fifo_full_sync[0], usb_to_avl_fifo_full};

        // After PLL lock, wait for FIFO flags to settle before allowing DATA writes.
        if (!avl_clk_locked_sync[1]) begin
            avl_usb_ready_delay_cnt <= 8'd0;
        end
        else if (!avl_usb_ready) begin
            avl_usb_ready_delay_cnt <= avl_usb_ready_delay_cnt + 8'd1;
        end

        // STATUS and RX_CNT are registered snapshots. Software reads the previous
        // Avalon-cycle snapshot, which is stable for the Avalon read transaction.
        avl_rx_count_reg <= {22'd0, usb_to_avl_fifo_usedw};
        avl_status_reg <= {2'd0,
                           usb_cdc_configured_status,
                           avl_any_error_latch,
                           avl_data_read_error_latch,
                           avl_data_write_error_latch,
                           usb_tx_irq_pending, usb_rx_irq_pending,
                           avl_to_usb_fifo_usedw_status, usb_to_avl_fifo_usedw_status,
                           4'd0, usb_to_avl_fifo_full_status, avl_to_usb_fifo_full_status,
                           avl_to_usb_fifo_empty_status, usb_to_avl_fifo_empty_status};

        if (avl_data_read_waitrequest) begin
            if (!usb_to_avl_fifo_empty) begin
                avs_s1_readdata <= {24'd0, usb_to_avl_fifo_rdata};
                usb_to_avl_fifo_rdreq_reg <= 1'b1;
                avl_data_read_pending <= 1'b1;
            end
            else begin
                avl_data_read_pending <= 1'b0;
            end
        end

        case ({avl_write_accept, avl_read_accept})
            2'b10: begin
                case (avs_s1_address) /* write process */
                        2'd0: begin /* data register */
                            // DATA write is accepted only when waitrequest is low and TX FIFO has room.
                            if (avs_s1_byteenable[0] && avl_to_usb_write_ready) begin
                                avl_to_usb_fifo_wdata_reg <= avs_s1_writedata[7:0];
                                avl_to_usb_fifo_wrreq_reg <= 1'b1;
                            end
                            else if (avs_s1_byteenable[0] && avl_usb_ready) begin
                                avl_data_write_error_latch <= 1'b1;
                            end
                        end
                        2'd1: begin /* status register */
                            /* Any write to STATUS clears FIFO overflow/underflow and DATA access error latches. */
                            fifo_error_flag_clear_reg <= 1'b1;
                            avl_data_write_error_latch <= 1'b0;
                            avl_data_read_error_latch  <= 1'b0;
                        end
                        2'd2: begin /* control register */
                            avl_ctrl_reg   <= avs_s1_writedata; /* dont care byteenable signals */
                        end
                      default: begin end
                endcase
            end
            2'b01: begin /* read process */
                case (avs_s1_address)
                        2'd0: begin /* read data */
                            /* DATA read data was staged during the waitrequest cycle. */
                        end
                        2'd1:    avs_s1_readdata <= avl_status_reg;
                        2'd2:    avs_s1_readdata <= avl_ctrl_reg;
                        2'd3:    avs_s1_readdata <= avl_rx_count_reg;
                        default: avs_s1_readdata <= 32'd0;
                endcase
            end
            default: begin end
        endcase
    end
end

// USB CDC IN endpoint sees valid data whenever the TX FIFO has data on its read side.
assign usb_cdc_tx_valid = !avl_to_usb_fifo_empty;

// TX FIFO: Avalon writes bytes, USB CDC reads bytes for host IN transfers.
usbfifo #(
        .fifodepth  (fifodepth),
        .fifowidth  (fifowidth)
    )
    u_usbfifo_to_usb (
    .aclr       (usb_fifo_aclr),
    /* write side */
    .wrclk      (csi_clockreset_clk),
    .wrreq      (avl_to_usb_fifo_wrreq_reg),
    .data       (avl_to_usb_fifo_wdata_reg),
    /* read side */
    .rdclk      (clk48mhz),
    .rdreq      (usb_cdc_tx_ready & !avl_to_usb_fifo_empty),
    .q          (usb_cdc_tx_data),

    .rdempty    (avl_to_usb_fifo_empty),
    .rdusedw    (),
    .wrfull     (avl_to_usb_fifo_full),
    .wrusedw    (avl_to_usb_fifo_usedw),
    .flag_clear (fifo_error_flag_clear_reg),
    .wr_overflow_pulse  (),
    .wr_overflow_latch  (avl_to_usb_fifo_overflow_latch),
    .rd_underflow_pulse (),
    .rd_underflow_latch (avl_to_usb_fifo_underflow_latch)
    );

   /* RX FIFO: USB CDC writes host OUT bytes, Avalon reads them through DATA. */
usbfifo #(
        .fifodepth  (fifodepth),
        .fifowidth  (fifowidth)
    )
    u_usbfifo_to_avb(
    .aclr       (usb_fifo_aclr),
    
    /* write side */
    .wrclk      (clk48mhz),
    .wrreq      (usb_cdc_rx_valid & usb_cdc_rx_ready),
    .data       (usb_cdc_rx_data),
    
    /* read side */
    .rdclk      (csi_clockreset_clk),
    .rdreq      (usb_to_avl_fifo_rdreq_reg),
    .q          (usb_to_avl_fifo_rdata),
    .rdusedw    (usb_to_avl_fifo_usedw),

    .rdempty    (usb_to_avl_fifo_empty),
    .wrfull     (usb_to_avl_fifo_full),
    .wrusedw    (),
    .flag_clear (fifo_error_flag_clear_reg),
    .wr_overflow_pulse  (),
    .wr_overflow_latch  (usb_to_avl_fifo_overflow_latch),
    .rd_underflow_pulse (),
    .rd_underflow_latch (usb_to_avl_fifo_underflow_latch)
    );

// Local USB clock generator. The CDC core uses the 48 MHz output.
usb_pll altpll_i(
    .inclk0 (avs_export_clk50_i),
    .c0     (clk48mhz),
    .c1     (clk96mhz),
    .c2     (clk12mhz),
    .locked (clk_locked)
    );

// USB CDC ACM core. This module owns USB enumeration and bulk IN/OUT transfers.
usb_cdc
  #( .VENDORID              (16'h1234),
     .PRODUCTID             (16'h5678),
     .IN_BULK_MAXPACKETSIZE ('d64),
     .OUT_BULK_MAXPACKETSIZE('d64),
     .BIT_SAMPLES           ('d4),
     .USE_APP_CLK           (0),
     .APP_CLK_RATIO         ('d4))
   u_usb_cdc (
             .clk_i(clk48mhz),
    // clk_i clock shall have a frequency of 12MHz*BIT_SAMPLES
             .rstn_i(usb_core_reset_n),
    // While rstn_i is low (active low), the module shall be reset

    // ---- to/from Application ------------------------------------
             .app_clk_i     (clk48mhz),
             .out_data_o    (usb_cdc_rx_data),
             .out_valid_o   (usb_cdc_rx_valid),
    // While out_valid_o is high, the out_data_o shall be valid and both
    //   out_valid_o and out_data_o shall not change until consumed.
             .out_ready_i   (usb_cdc_rx_ready),
    // When both out_valid_o and out_ready_i are high, the out_data_o shall
    //   be consumed.
             .in_data_i     (usb_cdc_tx_data),
             .in_valid_i    (usb_cdc_tx_valid),
    // While in_valid_i is high, in_data_i shall be valid.
             .in_ready_o    (usb_cdc_tx_ready),
    // When both in_ready_o and in_valid_i are high, in_data_i shall
    //   be consumed.
             .frame_o       (),
    // frame_o shall be last recognized USB frame number sent by USB host.
             .configured_o  (usb_cdc_configured),
    // While USB_CDC is in configured state, configured_o shall be high.

    // ---- to USB bus physical transmitters/receivers --------------
            .dp_pu_o(avs_export_dp_pu_o),  /* DP pull */
            .tx_en_o(avs_export_tx_en_o),      /* tri-state switch */
            .dp_tx_o(avs_export_dp_tx_o),      /* D+ out */
            .dn_tx_o(avs_export_dn_tx_o),      /* D- out */
            .dp_rx_i(avs_export_dp_rx_i),  /* D+ in */
            .dn_rx_i(avs_export_dn_rx_i)   /* D- in */
    );

// Accept host OUT bytes while the RX FIFO still has free space.
assign usb_cdc_rx_ready = !usb_to_avl_fifo_full;

endmodule
