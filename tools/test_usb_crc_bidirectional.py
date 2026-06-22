import argparse
import random
import sys
import time

import serial


TEST_BYTE_COUNT = 10000
NIOS_TX_HEADER = b"NIOS2PC\n"
PC_TX_HEADER = b"PC2NIOS\n"
PC_START_HEADER = b"START\n"


def make_random_payload(count, seed):
    rng = random.Random(seed)
    return bytes(rng.randint(1, 255) for _ in range(count))


def crc_low_byte(data):
    return sum(data) & 0xFF


def read_exact(ser, size, timeout_seconds, label):
    deadline = time.perf_counter() + timeout_seconds
    data = bytearray()

    while len(data) < size and time.perf_counter() < deadline:
        chunk = ser.read(size - len(data))
        if chunk:
            data.extend(chunk)
        else:
            time.sleep(0.001)

    if len(data) != size:
        raise TimeoutError(f"Timeout while reading {label}: got {len(data)} of {size} bytes")

    return bytes(data)


def find_header(ser, header, timeout_seconds, retry_write=None, retry_interval=0.25):
    deadline = time.perf_counter() + timeout_seconds
    next_retry = time.perf_counter()
    matched = 0
    captured = bytearray()

    while matched < len(header) and time.perf_counter() < deadline:
        now = time.perf_counter()
        if retry_write is not None and now >= next_retry:
            ser.write(retry_write)
            ser.flush()
            next_retry = now + retry_interval

        data = ser.read(1)
        if not data:
            time.sleep(0.001)
            continue

        byte = data[0]
        captured.append(byte)
        if byte == header[matched]:
            matched += 1
        else:
            matched = 1 if byte == header[0] else 0

    if matched != len(header):
        tail = bytes(captured[-80:])
        raise TimeoutError(f"Header {header!r} not found. Last bytes: {tail!r}")


def drain_input(ser, seconds):
    deadline = time.perf_counter() + seconds
    drained = 0

    while time.perf_counter() < deadline:
        waiting = ser.in_waiting
        data = ser.read(waiting if waiting > 0 else 1)
        if data:
            drained += len(data)
            deadline = time.perf_counter() + seconds
        else:
            time.sleep(0.001)

    return drained


def write_in_chunks(ser, data, chunk_size, chunk_delay):
    total = 0

    for offset in range(0, len(data), chunk_size):
        chunk = data[offset : offset + chunk_size]
        total += ser.write(chunk)
        if chunk_delay > 0:
            time.sleep(chunk_delay)

    ser.flush()
    return total


def main():
    parser = argparse.ArgumentParser(description="Verify AvbusbCtrl USB CDC data integrity in both directions.")
    parser.add_argument("port", help="Serial port, for example COM4")
    parser.add_argument("--baud", type=int, default=3000000, help="CDC baud setting")
    parser.add_argument("--count", type=int, default=TEST_BYTE_COUNT, help="Random byte count; must match Nios firmware")
    parser.add_argument("--seed", type=int, default=0x50435A31, help="PC random seed")
    parser.add_argument("--timeout", type=float, default=15.0, help="Read timeout per phase")
    parser.add_argument("--pc-tx-chunk", type=int, default=4096, help="PC-to-Nios write chunk size")
    parser.add_argument("--pc-tx-delay", type=float, default=0.0, help="Delay after each PC-to-Nios chunk in seconds")
    parser.add_argument("--drain-seconds", type=float, default=0.5, help="Quiet time used to drain stale input")
    parser.add_argument("--no-reset", action="store_true", help="Do not reset serial input/output buffers before test")
    args = parser.parse_args()

    if args.count != TEST_BYTE_COUNT:
        print(f"count must be {TEST_BYTE_COUNT} for the current Nios firmware", file=sys.stderr)
        return 2
    if args.pc_tx_chunk <= 0:
        print("pc-tx-chunk must be positive", file=sys.stderr)
        return 2

    try:
        ser = serial.Serial(
            args.port,
            args.baud,
            timeout=0,
            write_timeout=5,
            rtscts=False,
            dsrdtr=False,
        )
    except serial.SerialException as exc:
        print(f"Open failed: {exc}", file=sys.stderr)
        return 2

    with ser:
        if not args.no_reset:
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            drained = drain_input(ser, args.drain_seconds)
            if drained:
                print(f"Drained stale input: {drained} bytes")

        print("Waiting for Nios->PC packet; sending START repeatedly until Nios responds...")
        find_header(ser, NIOS_TX_HEADER, args.timeout, retry_write=PC_START_HEADER)
        nios_payload = read_exact(ser, args.count, args.timeout, "Nios payload")
        nios_crc = read_exact(ser, 1, args.timeout, "Nios CRC")[0]
        nios_calc_crc = crc_low_byte(nios_payload)
        nios_pass = nios_crc == nios_calc_crc

        print(
            f"Nios->PC: count={len(nios_payload)} "
            f"calc_crc=0x{nios_calc_crc:02X} nios_crc=0x{nios_crc:02X} "
            f"result={'PASS' if nios_pass else 'FAIL'}"
        )

        pc_payload = make_random_payload(args.count, args.seed)
        pc_crc = crc_low_byte(pc_payload)

        print(
            f"Sending PC->Nios packet: count={args.count} crc=0x{pc_crc:02X} "
            f"chunk={args.pc_tx_chunk} delay={args.pc_tx_delay:.4f}s"
        )
        pc_packet = PC_TX_HEADER + pc_payload + bytes([pc_crc])
        write_in_chunks(ser, pc_packet, args.pc_tx_chunk, args.pc_tx_delay)

        result_deadline = time.perf_counter() + args.timeout
        result_text = bytearray()
        while time.perf_counter() < result_deadline:
            data = ser.read(max(ser.in_waiting, 1))
            if data:
                result_text.extend(data)
                if b"\n" in result_text:
                    break
            else:
                time.sleep(0.001)

        text = bytes(result_text).decode("ascii", errors="replace").strip()
        print(f"Nios console over USB: {text if text else '<no result text>'}")

    pc_to_nios_pass = "NIOS_RX PASS" in text
    overall_pass = nios_pass and pc_to_nios_pass
    print(f"Overall result: {'PASS' if overall_pass else 'FAIL'}")
    return 0 if overall_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
