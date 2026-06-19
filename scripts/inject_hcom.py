#!/usr/bin/env python3
"""
inject_hcom.py - Inject files into a Husky Hunter MAME NVRAM.
By Kayto 04/05/2026
Licensed under the MIT License. See LICENSE file for details.

Default mode: injects HCOM.COM from HUNTER.BIN (auto-located).
Generic mode: injects any file when --file and --dest are supplied.

Usage:
    # HCOM mode (default):
    python inject_hcom.py <nvram> [output] [--hunter-bin PATH] [--inplace]

    # Generic mode:
    python inject_hcom.py <nvram> [output] --file SOURCE --dest DESTNAME [--inplace]

    nvram:         MAME NVRAM file to inject into
    output:        where to write result (omit with --inplace)
    --hunter-bin:  explicit path to HUNTER.BIN (HCOM mode only)
    --file:        source file to inject (generic mode)
    --dest:        destination filename on Hunter, e.g. DEMO1.HBA (generic mode)
    --inplace:     overwrite the input NVRAM file in-place

HUNTER.BIN is located automatically (HCOM mode):
  1. --hunter-bin PATH if supplied
  2. Next to this script  (dev: nvram_inject/HUNTER.BIN)
  3. ../HuskyHCOM/hcomw/HCOM.DOS/HUNTER.BIN  (RELEASE layout)

DEMOS Filesystem facts:
  - Bank1 (NVRAM 0x10000) holds the filesystem
  - 2KB blocks; bitmap at bank1 CPU 0x0040 AND common RAM CPU 0xD780 (both updated)
  - Directory: bank1 CPU 0x0100, 32-byte CP/M FCB-style entries, 16-bit LE block map
  - S1/S2 for HLINK COM files = byte-index of 0x1A header terminator
  - S1/S2 for all other files = sum(file_bytes) & 0xFF
"""

import sys
import os

# -- Layout constants ----------------------------------------------------------
NVRAM_SIZE       = 360448
BANK_SIZE        = 0xC000
N_BANKS          = 7

BANK_OFF         = [0x04000 + i * BANK_SIZE for i in range(N_BANKS)]

FS_BANK          = 1
FS_BANK_OFF      = BANK_OFF[FS_BANK]    # 0x10000

BITMAP_CPU       = 0x0040
BITMAP_LEN       = 0x50
DIR_START_CPU    = 0x0100
DIR_ENTRY_SIZE   = 0x20
DIR_MAX_ENTRIES  = 64
BLOCK_SIZE       = 0x0800

BITMAP_COMMON_CPU = 0xD780
BITMAP_COMMON_OFF = BITMAP_COMMON_CPU - 0xC000

FIRST_DATA_BLOCK  = 0x21

# -- Helpers -------------------------------------------------------------------

def bank1_off(cpu_addr):
    return FS_BANK_OFF + cpu_addr

def block_to_cpu(block):
    shifted = (block * 8) & 0xFFFF
    return shifted >> 8, (shifted & 0xFF) << 8

def block_to_nvram(block):
    bank, cpu = block_to_cpu(block)
    assert 0 <= bank < N_BANKS, f"Block {block} maps to non-existent bank {bank}"
    return BANK_OFF[bank] + cpu

def block_is_allocated(bitmap, block):
    return bool(bitmap[block // 8] & (1 << (7 - block % 8)))

def set_block_allocated(bitmap, block, allocated=True):
    bm = bytearray(bitmap)
    byte_idx, bit_idx = block // 8, 7 - block % 8
    if allocated:
        bm[byte_idx] |=  (1 << bit_idx)
    else:
        bm[byte_idx] &= ~(1 << bit_idx)
    return bytes(bm)

def find_free_blocks(bitmap, count):
    free = []
    for b in range(FIRST_DATA_BLOCK, 640):
        if not block_is_allocated(bitmap, b):
            free.append(b)
            if len(free) == count:
                return free
    raise RuntimeError(f"Not enough free blocks: need {count}, found {len(free)}")

def parse_name(name_str):
    name_str = name_str.upper().strip()
    if '.' in name_str:
        parts = name_str.rsplit('.', 1)
        return parts[0][:8].ljust(8), parts[1][:3].ljust(3)
    return name_str[:8].ljust(8), '   '

def _hlink_s1s2(file_data):
    """Return byte-index of 0x1A in first 128 bytes, or None if not HLINK."""
    for i, b in enumerate(file_data[:128]):
        if b == 0x1A:
            return i
    return None

# -- Directory -----------------------------------------------------------------

def read_dir_entry(nvram, idx):
    off = bank1_off(DIR_START_CPU + idx * DIR_ENTRY_SIZE)
    return nvram[off:off + DIR_ENTRY_SIZE]

def write_dir_entry(nvram, idx, entry):
    assert len(entry) == DIR_ENTRY_SIZE
    off = bank1_off(DIR_START_CPU + idx * DIR_ENTRY_SIZE)
    nvram[off:off + DIR_ENTRY_SIZE] = entry

def build_dir_entry(name, ext, rc, blocks, file_data=b''):
    assert len(name) == 8 and len(ext) == 3 and len(blocks) <= 8
    hlink_pos = _hlink_s1s2(file_data) if (file_data and file_data[0] == 0x18) else None
    checksum  = hlink_pos if hlink_pos is not None else (sum(file_data) & 0xFF)
    e = bytearray(32)
    e[0] = 0x00
    e[1:9]  = name.encode('ascii')
    e[9:12] = ext.encode('ascii')
    e[12]   = 0x00
    e[13] = e[14] = checksum
    e[15]   = rc & 0xFF
    for i, blk in enumerate(blocks[:8]):
        e[16 + i*2]     = blk & 0xFF
        e[16 + i*2 + 1] = (blk >> 8) & 0xFF
    return bytes(e)

def find_free_dir_slot(nvram):
    for idx in range(DIR_MAX_ENTRIES):
        entry = read_dir_entry(nvram, idx)
        if all(b == 0 for b in entry) or entry[0] == 0xE5:
            return idx
    raise RuntimeError("No free directory slots available")

def find_existing_file(nvram, name, ext):
    name_b, ext_b = name.encode('ascii'), ext.encode('ascii')
    for idx in range(DIR_MAX_ENTRIES):
        entry = read_dir_entry(nvram, idx)
        if entry[0] in (0xE5, 0x00) and all(b == 0 for b in entry[1:]):
            continue
        if entry[1:9] == name_b and entry[9:12] == ext_b:
            return idx
    return -1

# -- Core injection ------------------------------------------------------------

def inject(nvram_path, src_path, dest_name, output_path=None):
    """Inject src_path into the NVRAM as dest_name."""
    if output_path is None:
        output_path = nvram_path + '.injected'

    with open(nvram_path, 'rb') as f:
        nvram = bytearray(f.read())
    with open(src_path, 'rb') as f:
        file_data = f.read()

    assert len(nvram) == NVRAM_SIZE, \
        f"NVRAM size mismatch: {len(nvram)} != {NVRAM_SIZE}"

    name, ext  = parse_name(dest_name)
    file_size  = len(file_data)
    n_records  = (file_size + 127) // 128
    n_blocks   = (file_size + BLOCK_SIZE - 1) // BLOCK_SIZE

    hlink_pos = _hlink_s1s2(file_data) if (file_data and file_data[0] == 0x18) else None
    hlink_tag = f" [HLINK, S1/S2=0x{hlink_pos:02X}]" if hlink_pos is not None else ""
    print(f"Injecting '{src_path}' as '{name.rstrip()}.{ext.rstrip()}' ({file_size} bytes){hlink_tag}")
    print(f"  Records: {n_records}, Blocks needed: {n_blocks}")

    bm_off = bank1_off(BITMAP_CPU)
    bitmap = bytes(nvram[bm_off : bm_off + BITMAP_LEN])

    existing_idx = find_existing_file(nvram, name, ext)
    if existing_idx >= 0:
        existing   = read_dir_entry(nvram, existing_idx)
        old_blocks = [(existing[16+i*2] | (existing[16+i*2+1] << 8))
                      for i in range(8)
                      if (existing[16+i*2] | existing[16+i*2+1]) != 0]
        print(f"  Overwriting existing entry at slot {existing_idx}, freeing blocks {old_blocks}")
        for b in old_blocks:
            bitmap = set_block_allocated(bitmap, b, False)
        write_dir_entry(nvram, existing_idx, b'\xE5' + b'\x00' * 31)

    free_blocks = find_free_blocks(bitmap, n_blocks)
    print(f"  Allocated blocks: {[hex(b) for b in free_blocks]}")

    for i, blk in enumerate(free_blocks):
        nvram_blk_off = block_to_nvram(blk)
        chunk = file_data[i * BLOCK_SIZE : (i+1) * BLOCK_SIZE].ljust(BLOCK_SIZE, b'\x00')
        nvram[nvram_blk_off : nvram_blk_off + BLOCK_SIZE] = chunk
        bank, cpu = block_to_cpu(blk)
        print(f"  Block {hex(blk)}: NVRAM 0x{nvram_blk_off:05X} (bank{bank} CPU 0x{cpu:04X})")

    for b in free_blocks:
        bitmap = set_block_allocated(bitmap, b, True)

    dir_slot = find_free_dir_slot(nvram)
    blk_list = free_blocks + [0] * (8 - len(free_blocks))
    write_dir_entry(nvram, dir_slot, build_dir_entry(name, ext, n_records, blk_list, file_data))
    print(f"  Directory entry written at slot {dir_slot}")

    nvram[bm_off : bm_off + BITMAP_LEN]                       = bitmap
    nvram[BITMAP_COMMON_OFF : BITMAP_COMMON_OFF + BITMAP_LEN]  = bitmap
    print(f"  Bitmap updated at bank1 CPU 0x{BITMAP_CPU:04X} and common CPU 0x{BITMAP_COMMON_CPU:04X}")

    with open(output_path, 'wb') as f:
        f.write(nvram)
    print(f"\nOutput written to '{output_path}'")

# -- HCOM helpers --------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_hunter_bin(explicit=None):
    candidates = []
    if explicit:
        candidates.append(explicit)
    candidates.append(os.path.join(SCRIPT_DIR, 'HUNTER.BIN'))
    candidates.append(os.path.join(SCRIPT_DIR, '..', 'HuskyHCOM', 'hcomw', 'HCOM.DOS', 'HUNTER.BIN'))
    for p in candidates:
        p = os.path.normpath(p)
        if os.path.isfile(p):
            return p
    raise FileNotFoundError(
        "HUNTER.BIN not found. Run setup_hcom.sh first to extract hcomw/, "
        "or supply --hunter-bin PATH. Searched:\n" +
        "\n".join(f"  {os.path.normpath(c)}" for c in candidates if c != explicit)
    )

def inject_hcom(nvram_path, output_path=None, hunter_bin_path=None, inplace=False):
    hunter_bin = find_hunter_bin(hunter_bin_path)
    print(f"HUNTER.BIN : {hunter_bin}")
    if inplace:
        output_path = nvram_path
    elif output_path is None:
        output_path = nvram_path + '.hcom'
    inject(nvram_path, hunter_bin, 'HCOM.COM', output_path)
    print(f"\nHCOM.COM injected successfully -> {output_path}")
    if not inplace:
        print(f"Replace your MAME nvram file with '{output_path}'.")

# -- CLI -----------------------------------------------------------------------

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(
        description='Inject files into a Husky Hunter MAME NVRAM.\n'
                    'Default: inject HCOM.COM from HUNTER.BIN (auto-located).\n'
                    'Generic: supply --file and --dest to inject any file.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument('nvram',   help='MAME NVRAM file')
    parser.add_argument('output',  nargs='?', default=None,
                        help='Output NVRAM (default: <nvram>.hcom or <nvram>.injected)')
    parser.add_argument('--inplace',    action='store_true',
                        help='Overwrite input NVRAM in-place')
    parser.add_argument('--hunter-bin', default=None, metavar='PATH',
                        help='Explicit path to HUNTER.BIN (HCOM mode)')
    parser.add_argument('--file',  default=None, metavar='SOURCE',
                        help='Source file to inject (generic mode)')
    parser.add_argument('--dest',  default=None, metavar='DESTNAME',
                        help='Destination filename on Hunter, e.g. DEMO1.HBA (generic mode)')
    args = parser.parse_args()

    if bool(args.file) != bool(args.dest):
        parser.error('--file and --dest must be used together')

    if args.file:
        # Generic injection mode
        out = args.nvram if args.inplace else args.output
        inject(args.nvram, args.file, args.dest, out)
    else:
        # HCOM mode
        inject_hcom(args.nvram, args.output, args.hunter_bin, inplace=args.inplace)
