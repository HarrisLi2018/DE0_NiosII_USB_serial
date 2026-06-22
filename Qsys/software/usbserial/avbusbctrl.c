#include <stdio.h>

#include "io.h"
#include "system.h"
#include "priv/alt_busy_sleep.h"

#include "avbusbctrl.h"

/* Return the registered STATUS snapshot from the Avalon slave. */
unsigned int usbctrl_read_status(void)
{
    return IORD(USBCTRL_BASE, USBCTRL_STATUS_REG);
}

/* Any write to STATUS clears sticky DATA/FIFO error flags in AvbusbCtrl. */
void usbctrl_clear_errors(void)
{
    IOWR(USBCTRL_BASE, USBCTRL_STATUS_REG, 0);
}

unsigned int usbctrl_status_rx_usedw(unsigned int status)
{
    return (status & USBCTRL_STATUS_RX_USEDW_MASK) >> 8;
}

unsigned int usbctrl_status_tx_usedw(unsigned int status)
{
    return (status & USBCTRL_STATUS_TX_USEDW_MASK) >> 16;
}

void usbctrl_print_status(const char *tag, unsigned int status)
{
    /* Keep this format compact because it is printed through the JTAG UART. */
    printf("%s STATUS=0x%08x RX_EMPTY=%u TX_EMPTY=%u TX_FULL=%u RX_FULL=%u "
           "RX_USED=%u TX_USED=%u ERR=%u WERR=%u RERR=%u\n",
           tag,
           status,
           (status & USBCTRL_STATUS_RX_EMPTY) ? 1u : 0u,
           (status & USBCTRL_STATUS_TX_EMPTY) ? 1u : 0u,
           (status & USBCTRL_STATUS_TX_FULL) ? 1u : 0u,
           (status & USBCTRL_STATUS_RX_FULL) ? 1u : 0u,
           usbctrl_status_rx_usedw(status),
           usbctrl_status_tx_usedw(status),
           (status & USBCTRL_STATUS_ERROR) ? 1u : 0u,
           (status & USBCTRL_STATUS_WRITE_ERROR) ? 1u : 0u,
           (status & USBCTRL_STATUS_READ_ERROR) ? 1u : 0u);
}

unsigned int usbctrl_clear_errors_and_wait(void)
{
    unsigned int polls;
    unsigned int status;

    /* Error latches clear synchronously, so allow a few polling attempts. */
    for (polls = 0; polls < USBCTRL_ERROR_RETRY_LIMIT; ++polls) {
        usbctrl_clear_errors();
        alt_busy_sleep(1000);
        status = usbctrl_read_status();

        if ((status & USBCTRL_STATUS_ERROR) == 0) {
            return status;
        }
    }

    return usbctrl_read_status();
}

void usbctrl_disable_interrupts(void)
{
    IOWR(USBCTRL_BASE, USBCTRL_CONTROL_REG, 0);
}

int usbctrl_write_byte(unsigned char data)
{
    unsigned int polls;
    unsigned int error_retries = 0;

    /*
     * TX writes normally complete through hardware waitrequest. The STATUS
     * polling here is still useful for readable diagnostics if a sticky error
     * was left from an earlier transfer.
     */
    for (polls = 0; polls < USBCTRL_TX_TIMEOUT_POLLS; ++polls) {
        unsigned int status = usbctrl_read_status();

        if (status & USBCTRL_STATUS_ERROR) {
            if (error_retries < USBCTRL_ERROR_RETRY_LIMIT) {
                ++error_retries;
                usbctrl_print_status("Clearing TX-side error", status);
                usbctrl_clear_errors_and_wait();
                continue;
            }

            usbctrl_print_status("TX ERROR", status);
            return -1;
        }

        if ((status & USBCTRL_STATUS_TX_FULL) == 0) {
            IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data);
            return 0;
        }
    }

    usbctrl_print_status("TX timeout", usbctrl_read_status());
    return -1;
}

unsigned int usbctrl_write_bytes(const unsigned char *data, unsigned int length)
{
    unsigned int i;

    for (i = 0; (i + 8u) <= length; i += 8u) {
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 1u]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 2u]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 3u]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 4u]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 5u]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 6u]);
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i + 7u]);
    }

    for (; i < length; ++i) {
        IOWR(USBCTRL_BASE, USBCTRL_DATA_REG, data[i]);
    }

    return length;
}

int usbctrl_read_byte(unsigned char *data)
{
    /*
     * AvbusbCtrl holds Avalon waitrequest while the RX FIFO is empty. By the
     * time IORD returns, DATA contains a valid received byte.
     */
    *data = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
    return 0;
}

unsigned int usbctrl_read_bytes(unsigned char *data, unsigned int length)
{
    unsigned int i;

    for (i = 0; (i + 8u) <= length; i += 8u) {
        data[i] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 1u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 2u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 3u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 4u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 5u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 6u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
        data[i + 7u] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
    }

    for (; i < length; ++i) {
        data[i] = (unsigned char)(IORD(USBCTRL_BASE, USBCTRL_DATA_REG) & 0xffu);
    }

    return length;
}

int usbctrl_wait_byte(unsigned char *data)
{
    return usbctrl_read_byte(data);
}

int usbctrl_write_text(const char *text)
{
    while (*text != '\0') {
        if (usbctrl_write_byte((unsigned char)*text) != 0) {
            return -1;
        }
        ++text;
    }

    return 0;
}

static int usbctrl_write_hex_nibble(unsigned int value)
{
    value &= 0x0fu;
    return usbctrl_write_byte((unsigned char)((value < 10u) ? ('0' + value) : ('A' + value - 10u)));
}

int usbctrl_write_hex_byte(unsigned char value)
{
    /* Used by test code to send machine-readable PASS/FAIL details to PC. */
    if (usbctrl_write_hex_nibble((unsigned int)(value >> 4)) != 0) {
        return -1;
    }

    return usbctrl_write_hex_nibble((unsigned int)value);
}
