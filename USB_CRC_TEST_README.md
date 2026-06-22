# AvbusbCtrl USB CRC Test Guide

This document describes how to run the AvbusbCtrl USB CDC bidirectional data
integrity test.

## Test Purpose

The test verifies both USB data directions:

1. Nios II sends 10000 random bytes to the PC.
2. The PC calculates the low byte of the byte sum and compares it with the CRC
   byte sent by Nios II.
3. The PC sends 10000 random bytes to Nios II.
4. Nios II calculates the low byte of the byte sum and compares it with the CRC
   byte sent by the PC.

The CRC used by this test is:

```text
CRC = (sum of all 10000 data bytes) & 0xFF
```

Each random byte is in the range 1 to 255.

## Files

FPGA image:

```text
output_files/DE0_TOP.sof
```

Nios II application:

```text
Qsys/software/usbserial/usbserial.elf
```

Nios II source files:

```text
Qsys/software/usbserial/usbserialtest.c
Qsys/software/usbserial/avbusbctrl.c
Qsys/software/usbserial/avbusbctrl.h
```

PC test script:

```text
tools/test_usb_crc_bidirectional.py
```

## Build

Build the Nios II software:

```powershell
cd D:\prj\codex\DE0_NiosII_USB_serial\Qsys\software\usbserial
make DISABLE_ELFPATCH=1 DISABLE_STACKREPORT=1
```

Build the FPGA image when Verilog or Qsys hardware changes:

```powershell
cd D:\prj\codex\DE0_NiosII_USB_serial
quartus_sh --flow compile DE0_TOP
```

The generated SOF file is:

```text
D:\prj\codex\DE0_NiosII_USB_serial\output_files\DE0_TOP.sof
```

## Run Procedure

1. Program the FPGA with `output_files/DE0_TOP.sof`.

2. Download and run the Nios II ELF:

   ```text
   Qsys/software/usbserial/usbserial.elf
   ```

3. Open the Nios II console. The program should print:

   ```text
   AvbusbCtrl USB bidirectional CRC test start
   USBCTRL_BASE=0x01000000
   CRC rule: low byte of sum of 10000 random bytes in range 1..255
   Waiting for PC start header: START
   ```

4. Find the USB CDC COM port in Windows Device Manager.

5. Run the PC test script. Example for `COM8`:

   ```powershell
   cd D:\prj\codex\DE0_NiosII_USB_serial\tools
   python test_usb_crc_bidirectional.py COM8 --baud 3000000
   ```

## Expected PC Output

Example:

```text
Waiting for Nios->PC packet; sending START repeatedly until Nios responds...
Nios->PC: count=10000 calc_crc=0xCB nios_crc=0xCB result=PASS
Sending PC->Nios packet: count=10000 crc=0x82 chunk=4096 delay=0.0000s
Nios console over USB: NIOS_RX PASS count=10000 calc=0x82 pc=0x82
Overall result: PASS
```

## Expected Nios II Console Output

Example:

```text
AvbusbCtrl USB bidirectional CRC test start
USBCTRL_BASE=0x01000000
CRC rule: low byte of sum of 10000 random bytes in range 1..255
Initial STATUS=0x20000003 RX_EMPTY=1 TX_EMPTY=1 TX_FULL=0 RX_FULL=0 RX_USED=0 TX_USED=0 ERR=0 WERR=0 RERR=0
Waiting for PC start header: START
PC start header received
Nios->PC random TX start: 10000 bytes
Nios->PC TX done: count=10000 crc=0xcb sum_low=0xcb
Waiting for PC->Nios packet header: PC2NIOS
PC->Nios packet header received
PC->Nios random RX start: 10000 bytes
PC->Nios RX done: count=10000 calc_crc=0x82 pc_crc=0x82 result=PASS
Final STATUS=0x20000003 RX_EMPTY=1 TX_EMPTY=1 TX_FULL=0 RX_FULL=0 RX_USED=0 TX_USED=0 ERR=0 WERR=0 RERR=0
AvbusbCtrl USB bidirectional CRC test PASS
```

## PC Script Options

Default command:

```powershell
python test_usb_crc_bidirectional.py COM8 --baud 3000000
```

Use smaller PC-to-Nios chunks if the PC write side times out:

```powershell
python test_usb_crc_bidirectional.py COM8 --baud 3000000 --pc-tx-chunk 16 --pc-tx-delay 0.005
```

Useful options:

```text
--pc-tx-chunk N    Number of bytes per PC-to-Nios write chunk. Default: 4096.
--pc-tx-delay S    Delay after each PC-to-Nios chunk, in seconds. Default: 0.
--timeout S        Timeout per receive phase, in seconds. Default: 15.
--no-reset         Do not reset the serial input/output buffers before test.
```

## Protocol

PC starts the test by repeatedly sending:

```text
START\n
```

Nios II then sends:

```text
NIOS2PC\n
10000 data bytes
1 CRC byte
```

The PC then sends:

```text
PC2NIOS\n
10000 data bytes
1 CRC byte
```

Nios II returns an ASCII result line over USB:

```text
NIOS_RX PASS count=10000 calc=0x82 pc=0x82
```

or:

```text
NIOS_RX FAIL count=10000 calc=0x?? pc=0x??
```

## Troubleshooting

### PC Cannot Open COM Port

Close any terminal program that may already be using the COM port.

Check the COM port number in Windows Device Manager and rerun the command with
the correct port.

### PC Write Timeout

This usually means the PC is sending USB OUT data faster than the Nios II side
can drain it.

Try a smaller chunk and longer delay:

```powershell
python test_usb_crc_bidirectional.py COM8 --baud 3000000 --pc-tx-chunk 16 --pc-tx-delay 0.005
```

### Nios Does Not Receive START

Make sure the Nios II program is waiting at:

```text
Waiting for PC start header: START
```

Then run the Python script. The script repeatedly sends `START\n` until it sees
the Nios-to-PC packet header.

### CRC Fail

If Nios-to-PC fails, check the USB TX FIFO path.

If PC-to-Nios fails, check the USB RX FIFO path, especially:

```text
RX_EMPTY
RX_USED
RERR
ERR
```

The final STATUS should normally be:

```text
ERR=0 WERR=0 RERR=0
```

### Initial STATUS Looks Unstable

After FPGA programming or USB re-enumeration, rerun the Nios II program and the
Python script. The AvbusbCtrl hardware waits for the USB PLL and FIFO flags to
settle before normal DATA transfers.
