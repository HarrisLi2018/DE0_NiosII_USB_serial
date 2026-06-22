# DE0 Nios II USB Serial

Quartus II / Nios II project for a DE0 FPGA board with a custom Avalon-MM USB
CDC controller (`AvbusbCtrl`). The design connects a USB CDC full-speed core to
Nios II through Avalon registers and asynchronous FIFOs.

## Main Files

- `ip/AvbusbCtrl.v` - Avalon-MM USB CDC controller
- `Qsys/DE0Qsys/` - Qsys/Platform Designer system
- `Qsys/software/usbserial/` - Nios II USB serial test application
- `tools/test_usb_crc_bidirectional.py` - PC-side USB CDC CRC test
- `USB_CRC_TEST_README.md` - detailed build and test procedure

## Build

Build the Nios II software:

```powershell
cd D:\prj\codex\DE0_NiosII_USB_serial\Qsys\software\usbserial
make DISABLE_ELFPATCH=1 DISABLE_STACKREPORT=1
```

Build the FPGA image:

```powershell
cd D:\prj\codex\DE0_NiosII_USB_serial
quartus_sh --flow compile DE0_TOP
```

## Test

After programming the FPGA and downloading `usbserial.elf`, run:

```powershell
cd D:\prj\codex\DE0_NiosII_USB_serial\tools
python test_usb_crc_bidirectional.py COM8 --baud 3000000
```

The test sends 10000 random bytes in both directions and checks the low byte of
the payload sum as a simple CRC.

In the PC terminal will look like below:
```powershell
D:\DE0_NiosII_USB_serial\tools>python test_usb_crc_bidirectional.py COM8 --baud 3000000
Waiting for Nios->PC packet; sending START repeatedly until Nios responds...
Nios->PC: count=10000 calc_crc=0xCB nios_crc=0xCB result=PASS
Sending PC->Nios packet: count=10000 crc=0x82 chunk=4096 delay=0.0000s
Nios console over USB: NIOS_RX PASS count=10000 calc=0x82 pc=0x82
Overall result: PASS
```
and in the Nios console will show below:

```powershell
AvbusbCtrl USB bidirectional CRC test start
USBCTRL_BASE=0x01000000
CRC rule: low byte of sum of 10000 random bytes in range 1..255
Timestamp timer: 100000000 Hz
Initial STATUS=0x20000003 RX_EMPTY=1 TX_EMPTY=1 TX_FULL=0 RX_FULL=0 RX_USED=0 TX_USED=0 ERR=0 WERR=0 RERR=0
Waiting for PC start header: START
PC start header received
Nios->PC random TX start: 10000 bytes
Nios->PC TX done: count=10000 crc=0xcb sum_low=0xcb
Nios->PC TX payload speed: bytes=10000 elapsed=11709 us rate=854011 B/s 6.832 Mbit/s
Waiting for PC->Nios packet header: PC2NIOS
PC->Nios packet header received
PC->Nios random RX start: 10000 bytes
PC->Nios RX done: count=10000 calc_crc=0x82 pc_crc=0x82 result=PASS
PC->Nios RX payload speed: bytes=10000 elapsed=11252 us rate=888732 B/s 7.110 Mbit/s
Final STATUS=0x20000003 RX_EMPTY=1 TX_EMPTY=1 TX_FULL=0 RX_FULL=0 RX_USED=0 TX_USED=0 ERR=0 WERR=0 RERR=0
AvbusbCtrl USB bidirectional CRC test PASS
```

