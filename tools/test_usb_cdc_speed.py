import argparse
import sys
import time

import serial
from serial import SerialTimeoutException


def make_pattern(size):
    return bytes((i & 0xFF for i in range(size)))


def mbps(byte_count, elapsed):
    if elapsed <= 0:
        return 0.0
    return byte_count * 8 / elapsed / 1_000_000


def drain_input(ser, seconds=1.0):
    deadline = time.perf_counter() + seconds
    drained = 0
    while time.perf_counter() < deadline:
        data = ser.read(max(ser.in_waiting, 4096))
        if data:
            drained += len(data)
            deadline = time.perf_counter() + seconds
        else:
            time.sleep(0.001)
    return drained


def read_some(ser, max_size):
    waiting = ser.in_waiting
    if waiting <= 0:
        waiting = 1
    return ser.read(min(waiting, max_size))


def run_echo(ser, pattern, seconds, read_chunk, window):
    sent = 0
    received = 0
    mismatches = 0
    write_timeouts = 0
    expected = bytearray()

    start = time.perf_counter()
    deadline = start + seconds

    while time.perf_counter() < deadline:
        data = read_some(ser, read_chunk)
        if data:
            received += len(data)
            ref = expected[: len(data)]
            if data != ref:
                mismatches += 1
                idx = 0
                while idx < min(len(data), len(ref)) and data[idx] == ref[idx]:
                    idx += 1
                print(f"Mismatch near received byte {received - len(data) + idx}", file=sys.stderr)
                return sent, received, len(expected), mismatches, write_timeouts, time.perf_counter() - start
            del expected[: len(data)]

        if len(expected) < window:
            write_len = min(len(pattern), window - len(expected))
            try:
                written = ser.write(pattern[:write_len])
            except SerialTimeoutException:
                write_timeouts += 1
                time.sleep(0.001)
                continue
            sent += written
            expected.extend(pattern[:written])

    flush_deadline = time.perf_counter() + 3.0
    while expected and time.perf_counter() < flush_deadline:
        data = ser.read(min(max(ser.in_waiting, 1), len(expected), read_chunk))
        if not data:
            time.sleep(0.001)
            continue

        received += len(data)
        ref = expected[: len(data)]
        if data != ref:
            mismatches += 1
            break
        del expected[: len(data)]

    elapsed = time.perf_counter() - start
    return sent, received, len(expected), mismatches, write_timeouts, elapsed


def run_tx_only(ser, pattern, seconds):
    sent = 0
    write_timeouts = 0
    start = time.perf_counter()
    deadline = start + seconds

    while time.perf_counter() < deadline:
        try:
            sent += ser.write(pattern)
        except SerialTimeoutException:
            write_timeouts += 1
            time.sleep(0.001)

    elapsed = time.perf_counter() - start
    return sent, 0, 0, 0, write_timeouts, elapsed


def run_rx_only(ser, seconds, read_chunk):
    received = 0
    start = time.perf_counter()
    deadline = start + seconds

    while time.perf_counter() < deadline:
        data = ser.read(read_chunk)
        if data:
            received += len(data)
        else:
            time.sleep(0.001)

    elapsed = time.perf_counter() - start
    return 0, received, 0, 0, 0, elapsed


def main():
    parser = argparse.ArgumentParser(description="Measure USB CDC throughput.")
    parser.add_argument("port", help="Serial port, for example COM7")
    parser.add_argument("--baud", type=int, default=3000000, help="CDC baud setting")
    parser.add_argument("--seconds", type=float, default=10.0, help="Test duration")
    parser.add_argument("--chunk", type=int, default=4096, help="Write chunk size in bytes")
    parser.add_argument("--read-chunk", type=int, default=65536, help="Maximum read size in bytes")
    parser.add_argument("--window", type=int, default=16384, help="Maximum unverified echo bytes in flight")
    parser.add_argument(
        "--mode",
        choices=("echo", "tx", "rx"),
        default="echo",
        help="echo verifies loopback, tx measures host-to-device writes, rx measures device-to-host reads",
    )
    parser.add_argument("--target-mbps", type=float, default=3.0, help="PASS threshold")
    parser.add_argument(
        "--target-metric",
        choices=("auto", "tx", "rx", "combined"),
        default="auto",
        help="Metric used for PASS. auto uses combined for echo, tx for tx mode, and rx for rx mode.",
    )
    parser.add_argument("--drain-seconds", type=float, default=1.0, help="Quiet time used to drain stale input before test")
    parser.add_argument("--no-reset", action="store_true", help="Do not reset serial input/output buffers before test")
    args = parser.parse_args()

    if args.chunk <= 0 or args.read_chunk <= 0 or args.window <= 0:
        print("chunk, read-chunk, and window must be positive", file=sys.stderr)
        return 2

    pattern = make_pattern(args.chunk)

    try:
        ser = serial.Serial(
            args.port,
            args.baud,
            timeout=0,
            write_timeout=2,
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

        if args.mode == "echo":
            sent, received, pending, mismatches, write_timeouts, elapsed = run_echo(
                ser, pattern, args.seconds, args.read_chunk, args.window
            )
        elif args.mode == "tx":
            sent, received, pending, mismatches, write_timeouts, elapsed = run_tx_only(ser, pattern, args.seconds)
        else:
            sent, received, pending, mismatches, write_timeouts, elapsed = run_rx_only(ser, args.seconds, args.read_chunk)

    tx_mbps = mbps(sent, elapsed)
    rx_mbps = mbps(received, elapsed)
    combined_mbps = mbps(sent + received, elapsed)

    print(f"Mode: {args.mode}")
    print(f"Elapsed: {elapsed:.3f} s")
    print(f"Chunk: write={args.chunk} bytes, read={args.read_chunk} bytes, window={args.window} bytes")
    print(f"Sent: {sent} bytes ({tx_mbps:.3f} Mbit/s)")
    print(f"Received: {received} bytes ({rx_mbps:.3f} Mbit/s)")
    print(f"Combined bus payload: {combined_mbps:.3f} Mbit/s")
    print(f"Pending loopback bytes: {pending}")
    print(f"Mismatches: {mismatches}")
    print(f"Write timeouts: {write_timeouts}")

    target_metric = args.target_metric
    if target_metric == "auto":
        if args.mode == "echo":
            target_metric = "combined"
        elif args.mode == "tx":
            target_metric = "tx"
        else:
            target_metric = "rx"

    measured_mbps = {
        "tx": tx_mbps,
        "rx": rx_mbps,
        "combined": combined_mbps,
    }[target_metric]

    print(f"Target metric: {target_metric} ({measured_mbps:.3f} Mbit/s)")
    if measured_mbps >= args.target_mbps and mismatches == 0:
        print(f"PASS: {target_metric} throughput reached {args.target_mbps:.3f} Mbit/s")
    else:
        print(f"NOTE: {target_metric} throughput did not reach {args.target_mbps:.3f} Mbit/s")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
