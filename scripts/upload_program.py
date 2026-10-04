#!/usr/bin/env python3
"""Upload a readmemh hex program to the Arty UART monitor without rebuilding."""
import argparse
from pathlib import Path
import re
import time


def read_words(path):
    text = re.sub(r"/\*.*?\*/", "", Path(path).read_text(), flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    words = []
    address = 0
    for token in text.split():
        if token.startswith("@"):
            if not re.fullmatch(r"@[0-9a-fA-F]+", token):
                raise ValueError(f"Invalid address: {token}")
            address = int(token[1:], 16)
            if address >= 256:
                raise ValueError("Instruction RAM is limited to 256 words")
            continue
        if not re.fullmatch(r"[0-9a-fA-F]{8}", token):
            raise ValueError(f"Expected an eight-digit instruction word: {token}")
        if address >= 256:
            raise ValueError("Instruction RAM is limited to 256 words")
        while len(words) <= address:
            words.append(0x00000013)  # Fill sparse gaps with NOPs.
        words[address] = int(token, 16)
        address += 1
    if not words:
        raise ValueError("Program contains no instruction words")
    return words


def command(port, text):
    port.write((text + "\r\n").encode("ascii"))
    response = port.read_until(b"\n")
    if not response:
        raise RuntimeError(
            f"{text}: serial port opened, but the board sent no reply. "
            "Program build/arty_a7_35t/rv32i_fpga_top.bit (the UART-enabled build), "
            "check that this is the board's UART interface, and release BTN0. "
            "Use --list-ports and --probe to diagnose without uploading.")
    if response != b"OK\r\n":
        raise RuntimeError(f"{text}: expected OK, received {response!r}; check baud/bitstream")


def probe(port):
    """Query monitor status without stopping the CPU or changing its RAM."""
    port.reset_input_buffer()
    port.write(b"STATUS\r\n")
    deadline = time.monotonic() + 2
    responses = []
    pattern = rb"S [01] [01] [0-9A-F]{8} [0-9A-F]{8} [0-9A-F]{8}\r\n$"
    while time.monotonic() < deadline:
        response = port.read_until(b"\n")
        if not response:
            break
        responses.append(response)
        match = re.search(pattern, response)
        if match:
            return match.group().decode("ascii").strip()
    if responses:
        raise RuntimeError(f"No valid monitor STATUS reply; received {b''.join(responses)!r}")
    raise RuntimeError(
        "No bytes received. Verify the UART-enabled bitstream is programmed, "
        "select the board's UART USB interface, and release BTN0. "
        "The CPU-only bitstream cannot answer this probe.")


def loopback_test(port):
    """Test a separately programmed diagnostic bitstream, not the CPU loader."""
    payload = b"UART loopback 0123456789\r\n"
    port.reset_input_buffer()
    port.write(payload)
    response = port.read(len(payload))
    if response != payload:
        raise RuntimeError(
            f"Loopback failed: sent {payload!r}, received {response!r}. "
            "This test requires build/uart_loopback/uart_loopback.bit or "
            "build/uart_echo/uart_echo.bit programmed on the board.")
    return response


def upload(port, words, run=True):
    # STOP prevents a running program from continuously printing into replies.
    # Drain any in-flight CPU character and the STOP acknowledgement first.
    port.reset_input_buffer()
    port.write(b"STOP\r\n")
    port.flush()
    time.sleep(0.15)
    port.reset_input_buffer()
    command(port, "LOAD")
    for word in words:
        command(port, f"{word:08X}")
    if run:
        command(port, "RUN")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", nargs="?", help="COM5 on Windows, or /dev/ttyUSB1 on Linux")
    parser.add_argument("program", nargs="?", type=Path, help="32-bit readmemh instruction hex file")
    parser.add_argument("--list-ports", action="store_true", help="list USB serial interfaces and their identifiers")
    parser.add_argument("--probe", action="store_true", help="query STATUS without uploading or stopping the CPU")
    parser.add_argument("--loopback-test", action="store_true", help="test a programmed UART diagnostic bitstream")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--no-run", action="store_true", help="upload and leave CPU stopped")
    parser.add_argument("--monitor", action="store_true", help="display CPU serial output until Ctrl+C")
    args = parser.parse_args()
    if not args.list_ports and not args.port:
        parser.error("Specify a serial port, or use --list-ports")
    if not args.list_ports and not (args.probe or args.loopback_test) and args.program is None:
        parser.error("Specify a program hex file, or use --probe / --loopback-test")
    if args.probe and (args.program is not None or args.monitor or args.no_run):
        parser.error("--probe takes only a serial port; it does not upload or monitor a program")
    if args.loopback_test and (args.probe or args.program is not None or args.monitor or args.no_run):
        parser.error("--loopback-test takes only a serial port")
    if args.baud != 115200:
        parser.error("This bitstream uses 115200 baud; rebuild its BAUD parameter to use another rate")
    try:
        words = read_words(args.program) if not (args.list_ports or args.probe or args.loopback_test) else None
        import serial
        if args.list_ports:
            from serial.tools import list_ports
            ports = sorted(list_ports.comports(), key=lambda port: port.device)
            for port in ports:
                print(f"{port.device}: {port.description}\n  {port.hwid}")
            if not ports:
                print("No serial ports visible. Check the USB connection.")
            return
        with serial.Serial(args.port, args.baud, timeout=2, write_timeout=2,
                           bytesize=8, parity="N", stopbits=1,
                           xonxoff=False, rtscts=False, dsrdtr=False) as port:
            if args.probe:
                print("Monitor replied: " + probe(port))
                return
            if args.loopback_test:
                print("Loopback PASS: " + repr(loopback_test(port)))
                return
            upload(port, words, run=not args.no_run)
            print(f"Uploaded {len(words)} words; CPU {'stopped' if args.no_run else 'started'}.")
            if args.monitor and not args.no_run:
                print("Serial output (Ctrl+C to exit):", flush=True)
                while True:
                    output = port.read(port.in_waiting or 1)
                    if output:
                        print(output.decode("ascii", errors="replace"), end="", flush=True)
    except ImportError:
        parser.exit(1, "Install the serial library: python -m pip install pyserial\n")
    except KeyboardInterrupt:
        print()
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
