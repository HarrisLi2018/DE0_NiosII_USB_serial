// --------------------------------------------------------------------
// Copyright (c) 2009 by Terasic Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Terasic Technologies Inc
//                     356 Fu-Shin E. Rd Sec. 1. JhuBei City,
//                     HsinChu County, Taiwan
//                     302
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
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

`default_nettype none
module DE0_TOP
    (
        ////////////////////	Clock Input	 	////////////////////	 
        CLOCK_50,						//	50 MHz
        CLOCK_50_2,						//	50 MHz
        ////////////////////	Push Button		////////////////////
        BUTTON,							//	Pushbutton[2:0]
        ////////////////////	DPDT Switch		////////////////////
        SW,								//	Toggle Switch[9:0]
        ////////////////////	7-SEG Dispaly	////////////////////
        HEX0_D,							//	Seven Segment Digit 0
        HEX0_DP,						//	Seven Segment Digit DP 0
        HEX1_D,							//	Seven Segment Digit 1
        HEX1_DP,						//	Seven Segment Digit DP 1
        HEX2_D,							//	Seven Segment Digit 2
        HEX2_DP,						//	Seven Segment Digit DP 2
        HEX3_D,							//	Seven Segment Digit 3
        HEX3_DP,						//	Seven Segment Digit DP 3
        ////////////////////////	LED		////////////////////////
        LEDG,							//	LED Green[9:0]
        ////////////////////////	UART	////////////////////////
        UART_TXD,						//	UART Transmitter
        UART_RXD,						//	UART Receiver
        UART_CTS,						//	UART Clear To Send
        UART_RTS,						//	UART Request To Send
        /////////////////////	SDRAM Interface		////////////////
        DRAM_DQ,						//	SDRAM Data bus 16 Bits
        DRAM_ADDR,						//	SDRAM Address bus 13 Bits
        DRAM_LDQM,						//	SDRAM Low-byte Data Mask 
        DRAM_UDQM,						//	SDRAM High-byte Data Mask
        DRAM_WE_N,						//	SDRAM Write Enable
        DRAM_CAS_N,						//	SDRAM Column Address Strobe
        DRAM_RAS_N,						//	SDRAM Row Address Strobe
        DRAM_CS_N,						//	SDRAM Chip Select
        DRAM_BA_0,						//	SDRAM Bank Address 0
        DRAM_BA_1,						//	SDRAM Bank Address 1
        DRAM_CLK,						//	SDRAM Clock
        DRAM_CKE,						//	SDRAM Clock Enable
        ////////////////////	Flash Interface		////////////////
        FL_DQ,							//	FLASH Data bus 15 Bits
        FL_DQ15_AM1,					//	FLASH Data bus Bit 15 or Address A-1
        FL_ADDR,						//	FLASH Address bus 22 Bits
        FL_WE_N,						//	FLASH Write Enable
        FL_RST_N,						//	FLASH Reset
        FL_OE_N,						//	FLASH Output Enable
        FL_CE_N,						//	FLASH Chip Enable
        FL_WP_N,						//	FLASH Hardware Write Protect
        FL_BYTE_N,						//	FLASH Selects 8/16-bit mode
        FL_RY,							//	FLASH Ready/Busy
        ////////////////////	LCD Module 16X2		////////////////
        LCD_BLON,						//	LCD Back Light ON/OFF
        LCD_RW,							//	LCD Read/Write Select, 0 = Write, 1 = Read
        LCD_EN,							//	LCD Enable
        LCD_RS,							//	LCD Command/Data Select, 0 = Command, 1 = Data
        LCD_DATA,						//	LCD Data bus 8 bits
        ////////////////////	SD_Card Interface	////////////////
        SD_DAT0,						//	SD Card Data 0
        SD_DAT3,						//	SD Card Data 3
        SD_CMD,							//	SD Card Command Signal
        SD_CLK,							//	SD Card Clock
        SD_WP_N,						//	SD Card Write Protect
        ////////////////////	PS2		////////////////////////////
        PS2_KBDAT,						//	PS2 Keyboard Data
        PS2_KBCLK,						//	PS2 Keyboard Clock
        PS2_MSDAT,						//	PS2 Mouse Data
        PS2_MSCLK,						//	PS2 Mouse Clock
        ////////////////////	VGA		////////////////////////////
        VGA_HS,							//	VGA H_SYNC
        VGA_VS,							//	VGA V_SYNC
        VGA_R,   						//	VGA Red[3:0]
        VGA_G,	 						//	VGA Green[3:0]
        VGA_B,  						//	VGA Blue[3:0]
        ////////////////////	GPIO	////////////////////////////
        GPIO0_CLKIN,					//	GPIO Connection 0 Clock In Bus
        GPIO0_CLKOUT,					//	GPIO Connection 0 Clock Out Bus
        GPIO0_D,						//	GPIO Connection 0 Data Bus
        GPIO1_CLKIN,					//	GPIO Connection 1 Clock In Bus
        GPIO1_CLKOUT,					//	GPIO Connection 1 Clock Out Bus
        GPIO1_D							//	GPIO Connection 1 Data Bus
    );

////////////////////////	Clock Input	 	////////////////////////
input			CLOCK_50;				//	50 MHz
input			CLOCK_50_2;				//	50 MHz
////////////////////////	Push Button		////////////////////////
input	[2:0]	BUTTON;					//	Pushbutton[2:0]
////////////////////////	DPDT Switch		////////////////////////
input	[9:0]	SW;						//	Toggle Switch[9:0]
////////////////////////	7-SEG Dispaly	////////////////////////
output	[6:0]	HEX0_D;					//	Seven Segment Digit 0
output			HEX0_DP;				//	Seven Segment Digit DP 0
output	[6:0]	HEX1_D;					//	Seven Segment Digit 1
output			HEX1_DP;				//	Seven Segment Digit DP 1
output	[6:0]	HEX2_D;					//	Seven Segment Digit 2
output			HEX2_DP;				//	Seven Segment Digit DP 2
output	[6:0]	HEX3_D;					//	Seven Segment Digit 3
output			HEX3_DP;				//	Seven Segment Digit DP 3
////////////////////////////	LED		////////////////////////////
output	[9:0]	LEDG;					//	LED Green[9:0]
////////////////////////////	UART	////////////////////////////
output			UART_TXD;				//	UART Transmitter
input			UART_RXD;				//	UART Receiver
output			UART_CTS;				//	UART Clear To Send
input			UART_RTS;				//	UART Request To Send
///////////////////////		SDRAM Interface	////////////////////////
inout	[15:0]	DRAM_DQ;				//	SDRAM Data bus 16 Bits
output	[12:0]	DRAM_ADDR;				//	SDRAM Address bus 13 Bits
output			DRAM_LDQM;				//	SDRAM Low-byte Data Mask
output			DRAM_UDQM;				//	SDRAM High-byte Data Mask
output			DRAM_WE_N;				//	SDRAM Write Enable
output			DRAM_CAS_N;				//	SDRAM Column Address Strobe
output			DRAM_RAS_N;				//	SDRAM Row Address Strobe
output			DRAM_CS_N;				//	SDRAM Chip Select
output			DRAM_BA_0;				//	SDRAM Bank Address 0
output			DRAM_BA_1;				//	SDRAM Bank Address 1
output			DRAM_CLK;				//	SDRAM Clock
output			DRAM_CKE;				//	SDRAM Clock Enable
////////////////////////	Flash Interface	////////////////////////
inout	[14:0]	FL_DQ;					//	FLASH Data bus 15 Bits
inout			FL_DQ15_AM1;			//	FLASH Data bus Bit 15 or Address A-1
output	[21:0]	FL_ADDR;				//	FLASH Address bus 22 Bits
output			FL_WE_N;				//	FLASH Write Enable
output			FL_RST_N;				//	FLASH Reset
output			FL_OE_N;				//	FLASH Output Enable
output			FL_CE_N;				//	FLASH Chip Enable
output			FL_WP_N;				//	FLASH Hardware Write Protect
output			FL_BYTE_N;				//	FLASH Selects 8/16-bit mode
input			FL_RY;					//	FLASH Ready/Busy
////////////////////	LCD Module 16X2	////////////////////////////
inout	[7:0]	LCD_DATA;				//	LCD Data bus 8 bits
output			LCD_BLON;				//	LCD Back Light ON/OFF
output			LCD_RW;					//	LCD Read/Write Select, 0 = Write, 1 = Read
output			LCD_EN;					//	LCD Enable
output			LCD_RS;					//	LCD Command/Data Select, 0 = Command, 1 = Data
////////////////////	SD Card Interface	////////////////////////
inout			SD_DAT0;				//	SD Card Data 0
inout			SD_DAT3;				//	SD Card Data 3
inout			SD_CMD;					//	SD Card Command Signal
output			SD_CLK;					//	SD Card Clock
input			SD_WP_N;				//	SD Card Write Protect
////////////////////////	PS2		////////////////////////////////
inout		 	PS2_KBDAT;				//	PS2 Keyboard Data
inout			PS2_KBCLK;				//	PS2 Keyboard Clock
inout		 	PS2_MSDAT;				//	PS2 Mouse Data
inout			PS2_MSCLK;				//	PS2 Mouse Clock
////////////////////////	VGA			////////////////////////////
output			VGA_HS;					//	VGA H_SYNC
output			VGA_VS;					//	VGA V_SYNC
output	[3:0]	VGA_R;   				//	VGA Red[3:0]
output	[3:0]	VGA_G;	 				//	VGA Green[3:0]
output	[3:0]	VGA_B;   				//	VGA Blue[3:0]
////////////////////////	GPIO	////////////////////////////////
input	[1:0]	GPIO0_CLKIN;			//	GPIO Connection 0 Clock In Bus
output	[1:0]	GPIO0_CLKOUT;			//	GPIO Connection 0 Clock Out Bus
inout	[31:0]	GPIO0_D;				//	GPIO Connection 0 Data Bus
input	[1:0]	GPIO1_CLKIN;			//	GPIO Connection 1 Clock In Bus
output	[1:0]	GPIO1_CLKOUT;			//	GPIO Connection 1 Clock Out Bus
inout	[31:0]	GPIO1_D;				//	GPIO Connection 1 Data Bus

//=======================================================
//  REG/WIRE declarations
//=======================================================



//=======================================================
//  Structural coding
//=======================================================
 

wire    wClk200M, wClk10M;
    DE0Qsys u0 (
        .clk_50m_clk       (CLOCK_50),      //     clk_50m.clk
        .reset_reset_n     (usb_rstn),     //       reset.reset_n

        .clk200m_clk       (wClk200M),       //     clk200m.clk
        .clk10m_clk        (wClk10M),         //      clk10m.clk
        
              /* SDRAM interface */
        .sdramclk_clk      (DRAM_CLK),      //    dram_clk.clk
        .sdram_wires_addr  (DRAM_ADDR),     // sdram_wires.addr
        .sdram_wires_ba    ({DRAM_BA_1, DRAM_BA_0}),    //            .ba
        .sdram_wires_cas_n (DRAM_CAS_N),    //            .cas_n
        .sdram_wires_cke   (DRAM_CKE),      //            .cke
        .sdram_wires_cs_n  (DRAM_CS_N),     //            .cs_n
        .sdram_wires_dq    (DRAM_DQ),       //            .dq
        .sdram_wires_dqm   ({DRAM_UDQM, DRAM_LDQM}),   //            .dqm
        .sdram_wires_ras_n (DRAM_RAS_N),    //            .ras_n
        .sdram_wires_we_n  (DRAM_WE_N),     //            .we_n
              /* UART interface */
        .uart0_rxd         (UART_RXD),      //       uart0.rxd
        .uart0_txd         (UART_TXD),      //            .txd
              /* LEDG interface */
        .led_export        (),          //         led.export
              /* PLL interface */
        .areset_export     (0),             //      areset.export
        .locked_export     (/* no use */),  //      locked.export
        .phasedone_export  (/* no use */),   //   phasedone.export
        
        /* USB IF */
        .usbctrl_dp_pu_o   (GPIO0_D[17]),   //     usbctrl.dp_pu_o
        .usbctrl_tx_en_o   (tx_en_o),   //            .tx_en_o
        .usbctrl_dp_tx_o   (dp_tx_o),   //            .dp_tx_o
        .usbctrl_dn_tx_o   (dn_tx_o),   //            .dn_tx_o
        .usbctrl_dp_rx_i   (GPIO0_D[19]),   //            .dp_rx_i
        .usbctrl_dn_rx_i   (GPIO0_D[18]),   //            .dn_rx_i
        .usbctrl_Clk48M_i   (clk48mhz)    //            .clk50_i
    );

wire    tx_en_o, dp_tx_o, dn_tx_o;
/* turn on D+ and D- to tri-state*/
assign GPIO0_D[19] = tx_en_o ? dp_tx_o : 1'bz;
assign GPIO0_D[18] = tx_en_o ? dn_tx_o : 1'bz;
    
//assign LEDG[9] = GPIO1_D[15];  /* Data / CMD# */
//assign LEDG[8] = GPIO1_D[17];
//    
//
//fpga_top_usb_cdc fpga_top_usb_cdc(
//    // clock and reset
//    .clk50mhz   (CLOCK_50),     // connect to a 50MHz oscillator
//    .button     (BUTTON[0]),      // connect to a reset button, 0 is pressed, 1 is unpressed. If you don’t have a button, tie this signal to 1.
//    // USB signals
//    .usb_dp_pull(GPIO0_D[17]),  // connect to USB D+ by an 1.5k resistor
//    .usb_dp     (GPIO0_D[19]),       // connect to USB D+
//    .usb_dn     (GPIO0_D[18])        // connect to USB D-
//);

//wire wUSB_Dp_pull, wUSB_Dn, wUSB_Dp;
//
//
//fpga_top_usb_hid fpga_top_usb_hid(
//    // clock and reset
//    .clk50mhz   (CLOCK_50_2),     // connect to a 50MHz oscillator
//    .button     (BUTTON[0]),      // connect to a reset button, 0 is pressed, 1 is unpressed. If you don’t have a button, tie this signal to 1.
//    // USB signals
//    .usb_dp_pull(wUSB_Dp_pull),  // connect to USB D+ by an 1.5k resistor
//    .usb_dp     (GPIO0_D[19]),       // connect to USB D+
//    .usb_dn     (GPIO0_D[21])        // connect to USB D-
//);

/*  ==================usb_cdc-main run code ====================================== */ 

wire       clk48mhz, clk96mhz, clk12mhz;
wire       clk_locked;

usb_pll altpll_i(
    .inclk0 (CLOCK_50_2),
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


wire [7:0]  wFifo_RdData, wFifo_ToUSBData;
wire        wFifoEmpty, wFifoEmpty2;
wire        wUSBRdy;


assign usb_rstn = BUTTON[0] & clk_locked;
//assign usb_rstn = BUTTON[0];
assign LEDG[0] = clk_locked;
//assign LEDG[1] = USB_CONFIGURED;
assign LEDG[9:2] = 8'h00;





endmodule
