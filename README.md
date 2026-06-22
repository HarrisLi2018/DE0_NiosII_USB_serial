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
