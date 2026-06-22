#ifndef AVBUSBCTRL_H_
#define AVBUSBCTRL_H_

/*
 * Small helper library for the AvbusbCtrl Avalon-MM USB CDC controller.
 *
 * The hardware exposes four 32-bit Avalon registers:
 *   DATA   - byte-wide RX/TX data port
 *   STATUS - FIFO state, interrupt pending bits, and sticky error flags
 *   CTRL   - interrupt enable bits
 *   RX_CNT - number of bytes currently readable by Avalon
 *
 * DATA writes are flow-controlled in hardware with Avalon waitrequest.
 * DATA reads are also blocking at the hardware level: if the RX FIFO is
 * empty, the slave holds waitrequest until a byte is available.
 */
#include "system.h"

/* Avalon register offsets, in 32-bit words. */
#define USBCTRL_DATA_REG      0
#define USBCTRL_STATUS_REG    1
#define USBCTRL_CONTROL_REG   2
#define USBCTRL_RX_COUNT_REG  3

/* STATUS register bit definitions. */
#define USBCTRL_STATUS_RX_EMPTY       (1u << 0)
#define USBCTRL_STATUS_TX_EMPTY       (1u << 1)
#define USBCTRL_STATUS_TX_FULL        (1u << 2)
#define USBCTRL_STATUS_RX_FULL        (1u << 3)
#define USBCTRL_STATUS_RX_USEDW_MASK  (0xffu << 8)
#define USBCTRL_STATUS_TX_USEDW_MASK  (0xffu << 16)
#define USBCTRL_STATUS_RX_IRQ         (1u << 24)
#define USBCTRL_STATUS_TX_IRQ         (1u << 25)
#define USBCTRL_STATUS_WRITE_ERROR    (1u << 26)
#define USBCTRL_STATUS_READ_ERROR     (1u << 27)
#define USBCTRL_STATUS_ERROR          (1u << 28)
#define USBCTRL_STATUS_CONFIGURED     (1u << 29)

/* CTRL register bit definitions. */
#define USBCTRL_CTRL_RX_IRQ_ENABLE     (1u << 0)
#define USBCTRL_CTRL_TX_IRQ_ENABLE     (1u << 1)
#define USBCTRL_CTRL_ERROR_IRQ_ENABLE  (1u << 2)

/* Software guard limits used while polling TX/error state. */
#define USBCTRL_TX_TIMEOUT_POLLS   1000000u
#define USBCTRL_ERROR_RETRY_LIMIT  16u

/* Read the current STATUS register snapshot. */
unsigned int usbctrl_read_status(void);

/* Clear sticky DATA/FIFO error flags by writing the STATUS register. */
void usbctrl_clear_errors(void);

/* Clear sticky errors, then poll until STATUS.ERROR is deasserted or retries end. */
unsigned int usbctrl_clear_errors_and_wait(void);

/* Extract RX/TX FIFO used-word fields from a STATUS value. */
unsigned int usbctrl_status_rx_usedw(unsigned int status);
unsigned int usbctrl_status_tx_usedw(unsigned int status);

/* Print a decoded STATUS register line to the JTAG UART console. */
void usbctrl_print_status(const char *tag, unsigned int status);

/* Disable all AvbusbCtrl interrupt enables in CTRL. */
void usbctrl_disable_interrupts(void);

/*
 * Write one byte to the USB TX path.
 *
 * Returns 0 on success, -1 on timeout or unrecoverable sticky error.
 * The hardware waitrequest protects accepted DATA writes, while this function
 * also checks STATUS to report stale/full/error conditions cleanly.
 */
int usbctrl_write_byte(unsigned char data);

/*
 * Write multiple bytes to the USB TX path.
 *
 * This fast path relies on AvbusbCtrl hardware waitrequest for flow control
 * and avoids per-byte STATUS polling. Returns the number of bytes written.
 */
unsigned int usbctrl_write_bytes(const unsigned char *data, unsigned int length);

/*
 * Read one byte from the USB RX path.
 *
 * With the current hardware, DATA reads are blocking at the Avalon slave:
 * the CPU read transaction completes only after a byte is available.
 */
int usbctrl_read_byte(unsigned char *data);

/*
 * Read multiple bytes from the USB RX path.
 *
 * This uses repeated blocking DATA reads without per-byte function call
 * overhead in the caller. Returns the number of bytes copied.
 */
unsigned int usbctrl_read_bytes(unsigned char *data, unsigned int length);

/* Alias for usbctrl_read_byte(), kept to make intent explicit at header waits. */
int usbctrl_wait_byte(unsigned char *data);

/* Write a NUL-terminated ASCII string to the USB TX path. */
int usbctrl_write_text(const char *text);

/* Write one byte as two uppercase hexadecimal ASCII characters. */
int usbctrl_write_hex_byte(unsigned char value);

#endif /* AVBUSBCTRL_H_ */
