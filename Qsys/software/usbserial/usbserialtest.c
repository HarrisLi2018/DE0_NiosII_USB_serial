#include <stdio.h>

#include "priv/alt_busy_sleep.h"
#include "sys/alt_timestamp.h"

#include "avbusbctrl.h"

#define TEST_BYTE_COUNT     10000u
#define TX_BATCH_SIZE       128u
#define RX_BATCH_SIZE       128u

#define NIOS_TX_HEADER      "NIOS2PC\n"
#define PC_TX_HEADER        "PC2NIOS\n"
#define PC_START_HEADER     "START\n"

static unsigned int timestamp_ready = 0;
static unsigned int timestamp_hz = 0;
static unsigned char test_buffer[TEST_BYTE_COUNT];

static unsigned char prng_next_byte(unsigned int *state)
{
    *state = (*state * 1664525u) + 1013904223u;
    return (unsigned char)(((*state >> 24) % 255u) + 1u);
}

static unsigned char fill_random_test_buffer(unsigned int seed)
{
    unsigned int i;
    unsigned int crc_sum = 0;
    unsigned int rng_state = seed;

    for (i = 0; i < TEST_BYTE_COUNT; ++i) {
        test_buffer[i] = prng_next_byte(&rng_state);
        crc_sum += test_buffer[i];
    }

    return (unsigned char)(crc_sum & 0xffu);
}

static unsigned char calc_test_buffer_crc(void)
{
    unsigned int i;
    unsigned int crc_sum = 0;

    for (i = 0; i < TEST_BYTE_COUNT; ++i) {
        crc_sum += test_buffer[i];
    }

    return (unsigned char)(crc_sum & 0xffu);
}

static void init_speed_timer(void)
{
    if (alt_timestamp_start() == 0) {
        timestamp_hz = alt_timestamp_freq();
        timestamp_ready = (timestamp_hz != 0u);
    }

    if (timestamp_ready) {
        printf("Timestamp timer: %u Hz\n", timestamp_hz);
    }
    else {
        printf("Timestamp timer unavailable; throughput timing disabled\n");
    }
}

static unsigned int speed_timer_now(void)
{
    return (unsigned int)alt_timestamp();
}

static void print_speed_result(const char *tag,
                               unsigned int bytes,
                               unsigned int start_time,
                               unsigned int end_time)
{
    unsigned int elapsed_ticks;
    unsigned int elapsed_us;
    unsigned int bytes_per_sec;
    unsigned int mbit_milli;
    unsigned long long numerator;
    unsigned long long denominator;

    if (!timestamp_ready) {
        return;
    }

    elapsed_ticks = end_time - start_time;
    if (elapsed_ticks == 0u) {
        printf("%s speed: elapsed too short to measure\n", tag);
        return;
    }

    elapsed_us = (unsigned int)((((unsigned long long)elapsed_ticks * 1000000ull) +
                                (timestamp_hz / 2u)) / timestamp_hz);
    bytes_per_sec = (unsigned int)((((unsigned long long)bytes * timestamp_hz) +
                                   (elapsed_ticks / 2u)) / elapsed_ticks);

    numerator = (unsigned long long)bytes * 8ull * 1000ull * timestamp_hz;
    denominator = (unsigned long long)elapsed_ticks * 1000000ull;
    mbit_milli = (unsigned int)((numerator + (denominator / 2ull)) / denominator);

    printf("%s speed: bytes=%u elapsed=%u us rate=%u B/s %u.%03u Mbit/s\n",
           tag,
           bytes,
           elapsed_us,
           bytes_per_sec,
           mbit_milli / 1000u,
           mbit_milli % 1000u);
}

static int send_nios_to_pc_packet(void)
{
    unsigned int offset;
    unsigned char crc;
    unsigned int tx_start_time = 0;
    unsigned int tx_end_time = 0;

    printf("Nios->PC random TX start: %u bytes\n", TEST_BYTE_COUNT);
    crc = fill_random_test_buffer(0x4e494f53u); /* "NIOS" */

    if (usbctrl_write_text(NIOS_TX_HEADER) != 0) {
        return -1;
    }

    if (timestamp_ready) {
        tx_start_time = speed_timer_now();
    }

    for (offset = 0; offset < TEST_BYTE_COUNT; offset += TX_BATCH_SIZE) {
        unsigned int chunk = TEST_BYTE_COUNT - offset;

        if (chunk > TX_BATCH_SIZE) {
            chunk = TX_BATCH_SIZE;
        }

        if (usbctrl_write_bytes(&test_buffer[offset], chunk) != chunk) {
            return -1;
        }
    }

    if (usbctrl_write_byte(crc) != 0) {
        return -1;
    }

    if (timestamp_ready) {
        tx_end_time = speed_timer_now();
    }

    printf("Nios->PC TX done: count=%u crc=0x%02x sum_low=0x%02x\n",
           TEST_BYTE_COUNT,
           (unsigned int)crc,
           (unsigned int)crc);
    print_speed_result("Nios->PC TX payload", TEST_BYTE_COUNT, tx_start_time, tx_end_time);

    return 0;
}

static int wait_for_header(const char *header, const char *tag)
{
    unsigned int matched = 0;
    unsigned int header_len = 0;

    while (header[header_len] != '\0') {
        ++header_len;
    }

    printf("Waiting for %s header: %s", tag, header);

    while (matched < header_len) {
        unsigned char data;

        if (usbctrl_wait_byte(&data) != 0) {
            return -1;
        }

        if (data == (unsigned char)header[matched]) {
            ++matched;
        }
        else {
            matched = (data == (unsigned char)header[0]) ? 1u : 0u;
        }
    }

    printf("%s header received\n", tag);
    return 0;
}

static int receive_pc_to_nios_packet(void)
{
    unsigned int offset;
    unsigned char rx_crc;
    unsigned char calc_crc;
    unsigned int rx_start_time = 0;
    unsigned int rx_end_time = 0;
    int pass;

    if (wait_for_header(PC_TX_HEADER, "PC->Nios packet") != 0) {
        return -1;
    }

    printf("PC->Nios random RX start: %u bytes\n", TEST_BYTE_COUNT);

    if (timestamp_ready) {
        rx_start_time = speed_timer_now();
    }

    for (offset = 0; offset < TEST_BYTE_COUNT; offset += RX_BATCH_SIZE) {
        unsigned int chunk = TEST_BYTE_COUNT - offset;

        if (chunk > RX_BATCH_SIZE) {
            chunk = RX_BATCH_SIZE;
        }

        if (usbctrl_read_bytes(&test_buffer[offset], chunk) != chunk) {
            return -1;
        }
    }

    if (usbctrl_read_byte(&rx_crc) != 0) {
        return -1;
    }

    if (timestamp_ready) {
        rx_end_time = speed_timer_now();
    }

    calc_crc = calc_test_buffer_crc();
    pass = (calc_crc == rx_crc);

    printf("PC->Nios RX done: count=%u calc_crc=0x%02x pc_crc=0x%02x result=%s\n",
           TEST_BYTE_COUNT,
           (unsigned int)calc_crc,
           (unsigned int)rx_crc,
           pass ? "PASS" : "FAIL");
    print_speed_result("PC->Nios RX payload", TEST_BYTE_COUNT, rx_start_time, rx_end_time);

    usbctrl_write_text(pass ? "NIOS_RX PASS count=10000 calc=0x" :
                              "NIOS_RX FAIL count=10000 calc=0x");
    usbctrl_write_hex_byte(calc_crc);
    usbctrl_write_text(" pc=0x");
    usbctrl_write_hex_byte(rx_crc);
    usbctrl_write_text("\r\n");

    return pass ? 0 : -1;
}

int main(void)
{
    int result;

    printf("AvbusbCtrl USB bidirectional CRC test start\n");
    printf("USBCTRL_BASE=0x%08x\n", (unsigned int)USBCTRL_BASE);
    printf("CRC rule: low byte of sum of %u random bytes in range 1..255\n", TEST_BYTE_COUNT);
    init_speed_timer();

    usbctrl_disable_interrupts();
    usbctrl_print_status("Initial", usbctrl_clear_errors_and_wait());

    if (wait_for_header(PC_START_HEADER, "PC start") != 0) {
        result = -1;
    }
    else {
        result = send_nios_to_pc_packet();
    }

    if (result == 0) {
        result = receive_pc_to_nios_packet();
    }

    usbctrl_print_status("Final", usbctrl_read_status());
    printf("AvbusbCtrl USB bidirectional CRC test %s\n", (result == 0) ? "PASS" : "FAIL");

    while (1) {
        alt_busy_sleep(1000000);
    }

    return (result == 0) ? 0 : 1;
}
