#!/usr/bin/env python3
"""serial_bridge.py - TCP bridge between MAME's null_modem bitbanger and a terminal emulator.
By Kayto 04/05/2026
Licensed under the MIT License. See LICENSE file for details.

MAME's ``-bitb socket.HOST:PORT`` only operates as a TCP *client*, and most
terminal emulators (Tera Term raw, PuTTY raw, netcat...) also operate as
clients. This little relay listens on two ports and pipes bytes between
the first accepted connection on each side.

Typical use::

    python serial_bridge.py --mame-port 5706 --term-port 5707
    # then in another shell:
    .\\sdlhunter.exe hunter -bios 4 -window -ramsize 352K -rompath roms \\
        -serial null_modem -bitb socket.127.0.0.1:5706
    # and connect Tera Term / PuTTY (raw mode) to 127.0.0.1:5707

The bridge runs until either side disconnects or Ctrl+C is pressed.
"""
from __future__ import annotations

import argparse
import os
import socket
import sys
import threading
import time


BANNER = r"""
============================================================
  Hunter MAME <-> Terminal bridge
============================================================
  Connect a terminal emulator to:  127.0.0.1:{term_port}
  MAME -bitb target               :  socket.127.0.0.1:{mame_port}

  Tera Term (manual setup):
    1. File -> New connection...
    2. Select "TCP/IP"
    3. Host    : 127.0.0.1
    4. Service : "Other", TCP port: {term_port}
    5. (Setup -> Terminal) New-line: Receive=AUTO, Transmit=CR
       Local echo: ON if you want to see what you type
    6. (Setup -> Serial port) is NOT used -- this is a raw TCP connection

  PuTTY (manual setup):
    Connection type: "Raw"   Host: 127.0.0.1   Port: {term_port}

  netcat:    nc 127.0.0.1 {term_port}

  The Hunter UART defaults to 4800 8N1 (FIX-5 patch); the bridge itself
  is a dumb byte pipe and does not care about baud/parity/framing.
============================================================
"""


def _accept_one(port: int, label: str) -> socket.socket:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", port))
    srv.listen(1)
    print(f"[bridge] waiting for {label} on 127.0.0.1:{port} ...", flush=True)
    conn, addr = srv.accept()
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    print(f"[bridge] {label} connected from {addr[0]}:{addr[1]}", flush=True)
    srv.close()
    return conn


def _hexdump(prefix: str, data: bytes) -> None:
    hx = ' '.join(f'{b:02X}' for b in data)
    txt = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data)
    print(f"[{prefix}] ({len(data):3d}) {hx:<48}  |{txt}|", flush=True)


def _pump(src: socket.socket, dst: socket.socket, label: str,
          stop: threading.Event, verbose: bool = False,
          write_lock: threading.Lock | None = None) -> None:
    try:
        while not stop.is_set():
            data = src.recv(4096)
            if not data:
                break
            if verbose:
                _hexdump(label, data)
            if write_lock:
                with write_lock:
                    dst.sendall(data)
            else:
                dst.sendall(data)
    except OSError:
        pass
    finally:
        stop.set()
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass
        print(f"[bridge] {label} closed", flush=True)


STDIN_HELP = """
[bridge] Stdin commands (type at the bridge terminal):
  !file <path>   stream a binary file to the Hunter (chunk/pace rate)
  !chunk <n>     set chunk size in bytes      (default: 16)
  !pace <ms>     set pause between chunks ms  (default: 100)
  !sleep <ms>    pause for <ms> milliseconds
  <any text>     sent as raw bytes + CR to the Hunter
"""


def _stdin_handler(mame_sock: socket.socket, stop: threading.Event,
                   write_lock: threading.Lock) -> None:
    """Read stdin commands and inject bytes directly into the MAME socket."""
    chunk_size = 16
    pace_ms = 100
    print(STDIN_HELP, flush=True)
    try:
        for raw in sys.stdin:
            if stop.is_set():
                break
            line = raw.rstrip('\n').rstrip('\r')
            if line.startswith('!file '):
                path = line[6:].strip()
                if not os.path.isfile(path):
                    print(f'[bridge] !file: not found: {path}', flush=True)
                    continue
                fsize = os.path.getsize(path)
                sent = 0
                try:
                    with open(path, 'rb') as f:
                        while not stop.is_set():
                            chunk = f.read(chunk_size)
                            if not chunk:
                                break
                            with write_lock:
                                mame_sock.sendall(chunk)
                            sent += len(chunk)
                            pct = 100 * sent / fsize
                            print(f'\r[bridge] !file {sent}/{fsize} ({pct:.1f}%)',
                                  end='', flush=True)
                            time.sleep(pace_ms / 1000.0)
                    print(f'\n[bridge] !file done: {sent} bytes sent.', flush=True)
                except OSError as exc:
                    print(f'\n[bridge] !file error: {exc}', flush=True)
            elif line.startswith('!sleep '):
                try:
                    ms = int(line[7:].strip())
                    time.sleep(ms / 1000.0)
                    print(f'[bridge] slept {ms} ms', flush=True)
                except ValueError:
                    print('[bridge] !sleep: expected integer ms', flush=True)
            elif line.startswith('!chunk '):
                try:
                    chunk_size = int(line[7:].strip())
                    print(f'[bridge] chunk = {chunk_size} bytes', flush=True)
                except ValueError:
                    print('[bridge] !chunk: expected integer', flush=True)
            elif line.startswith('!pace '):
                try:
                    pace_ms = int(line[6:].strip())
                    print(f'[bridge] pace = {pace_ms} ms', flush=True)
                except ValueError:
                    print('[bridge] !pace: expected integer ms', flush=True)
            elif line:
                # Send raw text + CR to Hunter
                with write_lock:
                    mame_sock.sendall((line + '\r').encode('latin-1', errors='replace'))
    except (OSError, EOFError):
        pass


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--mame-port", type=int, default=5706,
                   help="port MAME's -bitb connects to (default: 5706)")
    p.add_argument("--term-port", type=int, default=5707,
                   help="port the terminal emulator connects to (default: 5707)")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="hex-dump every byte that crosses the bridge in either direction")
    p.add_argument("--tag", default=None,
                   help="opaque marker string (used by launchers to locate the process via wmic)")
    args = p.parse_args(argv)

    if args.mame_port == args.term_port:
        print("error: --mame-port and --term-port must differ", file=sys.stderr)
        return 2

    print(BANNER.format(mame_port=args.mame_port, term_port=args.term_port), flush=True)

    # Accept both ends in parallel so launch order doesn't matter.
    holder: dict[str, socket.socket] = {}

    def _accept(port: int, label: str) -> None:
        holder[label] = _accept_one(port, label)

    t_mame = threading.Thread(target=_accept, args=(args.mame_port, "MAME"), daemon=True)
    t_term = threading.Thread(target=_accept, args=(args.term_port, "terminal"), daemon=True)
    t_mame.start()
    t_term.start()
    t_mame.join()
    t_term.join()

    mame_sock = holder["MAME"]
    term_sock = holder["terminal"]
    print("[bridge] both sides connected, relaying...", flush=True)

    stop = threading.Event()
    mame_write_lock = threading.Lock()
    t1 = threading.Thread(target=_pump,
                          args=(mame_sock, term_sock, "MAME->term", stop, args.verbose),
                          daemon=True)
    t2 = threading.Thread(target=_pump,
                          args=(term_sock, mame_sock, "term->MAME", stop, args.verbose,
                                mame_write_lock),
                          daemon=True)
    t1.start()
    t2.start()

    t_stdin = threading.Thread(target=_stdin_handler,
                               args=(mame_sock, stop, mame_write_lock),
                               daemon=True)
    t_stdin.start()

    try:
        while not stop.is_set():
            stop.wait(0.5)
    except KeyboardInterrupt:
        print("[bridge] Ctrl+C, shutting down", flush=True)
        stop.set()

    for s in (mame_sock, term_sock):
        try:
            s.close()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
