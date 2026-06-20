# Husky Hunter (1983) -- MAME Emulation Status

**Standalone release summary. Status as of 2026-06-18.**

A self-contained assessment of how faithfully the in-tree MAME `hunter` driver
reproduces the 1983 Husky Hunter, derived from full ROM analysis and validated
by real-hardware-vs-MAME probes and MAME-debugger observation.

**ROM image SHA1:** `4EFA85555EEE1D61B8C577213BE8DB227C4ECFFD` (concatenated
6x8KB EPROMs, DEMOS 2.2 9G06).

**Headline:** across a comprehensive set of test programs the ROM<->MAME hardware
contract held end-to-end -- paged-RAM banking, overlay loading, bank-switching,
interrupt arming, and interrupt-vector fetching all behaved correctly, with **no
ROM-derived hardware-contract gaps observed**. This reflects the programs and paths
actually exercised (section 5.4 lists what remains untested); it is a strong
evidence-based result, not a proof that no gaps exist.

- - -

## 1\. How to read this document

* **[OK]** \-\- behaviour is in the ROM and verified working in current MAME
* **[PARTIAL]** \-\- partly implemented; specific corners broken or unverified
* **[GAP]** \-\- present in ROM\, missing or non\-functional in MAME
* **[UNKNOWN]** \-\- ROM exercises it\, MAME state untested \(not a known defect\)

- - -

## 2\. Memory map \(ROM\-derived hardware contract\)

```
0000H-1FFFH    EPROM 0 (ic50) -- vectors, NMI stub bank, RST 18/20 dispatchers
                                 + tables, paged-RAM record store, BASIC interpreter core
2000H-3FFFH    EPROM 1 (ic51) -- BASIC tokenizer/detokenizer, operator-dispatch table,
                                 BCD float primitives, PUTCHAR cluster
4000H-5FFFH    EPROM 2 (ic52) -- app warm-init, V24 serial TX, text editor,
                                 keyboard scan, graphics char output
6000H-7FFFH    EPROM 3 (ic53) -- HD61830 LCD drivers, V24 init, baud tables,
                                 sound init, bisync FSM, RST 18H BIOS targets,
                                 interrupt-arming subsystem, tape-TX bit cluster
8000H-9FFFH    EPROM 4 (ic54) -- BASIC main loop, graphics primitives
                                 (LINE/PSET), LIST output, keyword handler table
A000H-BFFFH    EPROM 5 (ic55) -- DEMOS OS REPL, command dispatch table,
                                 .SYS overlay model, RAM-disk file I/O,
                                 HD61830 fonts, font-overlay code cluster
C000H-DFFFH    Common RAM     -- NVRAM-backed
E000H-EFFFH    Paged RAM      -- 4 KB window; boot-time LDIR copy of ROM 0000H-0FFFH;
                                 holds RST 18/20 trampolines + dispatch/font overlay
F000H-FFFFH    Common RAM     -- system variables, stack, FP heap
```

**CPU:** NSC800 (Z80-compatible core with NSC800-specific interrupt vectors).
On the 1983 Hunter the six EPROMs are flat at 0000H-BFFFH when bank-select is
clear -- there is no ROM banking.

- - -

## 3\. Bank\-select \+ paging model

**Port E0H bit 7 controls what is mapped at CPU 0x0000-0xBFFF (bank-1):**

* bit 7 = **0** \-\- ROM mapped at 0000H\-BFFFH \(flat\)
* bit 7 = **1** \-\- paged RAM mapped at 0000H\-BFFFH; E000H\-EFFFH window stays RAM

The **E000-EFFF window** is always RAM and at cold boot is populated by an LDIR
copy of ROM 0000-0FFF. This boot mirror lets interrupt handlers and RST
trampolines keep working when bank-1 is switched to paged RAM. Inside the window
a 0x700-byte sub-region at `E72A-EE29` is an **overlay area** shared between two
states:

| State | Marker (E72AH) | Source | Resident content |
| ----- | -------------- | ------ | ---------------- |
| Dispatch overlay | `FFH` | ROM `072A-0FFF` | RST 20H targets + paged-RAM record-store API |
| Font overlay | `AAH` | ROM `BA60-BFFF` | Font-overlay code cluster (36 entry points) |

During normal display the font overlay is resident. An RST 20H call LDIRs the
dispatch overlay in, runs the target, then LDIRs the font overlay back.

A routine in either overlay can be reached by its window address
(`live_addr = E72A + (ROM_addr - overlay_source_base)`); the firmware calls some
font-overlay primitives this way (e.g. a page-restore helper whose ROM source is
at BB19 is called at its runtime address E7E3 from across the ROM).

- - -

## 4\. Interrupt model

### 4.1 NMI path -- Timer A -> 0x0066 -> F814H

* **TX-gated by construction** \-\- fires only when serial TX has armed Timer\-0
into NMI mode; at idle it does not fire. Not a MAME limitation; this is how
the firmware works.
* Vector at `0x0066` is `C3 14 F8` (`JP F814H`). The handler installed at F814H
is the serial-TX bit-output template, copied in during V24 init.
* The NMI vector at `0x0066` is **not** covered by the firmware's per-bank
page-zero mirror (that copy is only 64 bytes, `0x0000-0x003F`; `0x0066` lies
past it). Confirmed on real hardware: in paged-RAM mode the NMI vector slot
reads back live application data (`20 20 00`), not `C3 14 F8` \-\- the paged bank
holds no NMI-vector copy. So MAME installs a ROM read-shadow over
`0x0066-0x0068` so the vector fetch always reads `C3 14 F8` regardless of bank
state. **[OK]** for the vector fetch.
* **Scope note.** That shadow is *permanent* (it intercepts all reads of those 3
bytes), slightly broader than the real hardware, which forces ROM only during
the NMI-acknowledge cycle. Identical for the vector fetch (both read ROM); a
normal data read of `0x0066-0x0068` differs (MAME -> ROM, hardware -> live RAM).
Harmless unless some code reads those exact 3 bytes as data -- an open question,
not a known defect.

### 4.2 RSTA path -- Timer B -> RSTA -> 0x003C -> FDFB

* <b>The active interrupt vector is `0x003C`</b> (the NSC800's dedicated RSTA
vector), containing `C3 FB FD` (`JP FDFB` -> the installed timer ISR,
`TIMER_AB_ISR`). The generic Z80 IM-1 vector at `0x0038` (`C3 C6 FA`) exists
in the ROM image but is **not** the address the NSC800 vectors through for
RSTA -- confirmed by MAME watchpoints (int-ack fetches land at `0x003C`, never
`0x0038`).
* **RSTA is active, not dormant** \-\- armed during normal boot/init \(NSC800
interrupt-control register programmed to enable RSTA; timer ISR installed),
firing \~61 Hz. A separate `0x0038`/`FAC6`/SOUND-callback trampoline is
installed only in tape mode and *is* dormant at idle, but that is a different
path, not how RSTA actually vectors.
* **[OK] -- gap closed by firmware construction.** A forced-window test
(deliberately holding bank-1 in paged-RAM mode for \~400 ms with interrupts
enabled) caught RSTA firing *inside* a paged-RAM window: the `0x003C` vector
fetch read **correct ROM bytes** (`C3 FB FD`) and the CPU jumped to the ISR.
The reason is structural -- **the paged-RAM bank carries a copy of the low ROM
vectors** \-\- so the vector fetch reads the correct jump regardless of bank
state. The previously-suspected "vector fetch reads RAM garbage in paged-RAM
mode" gap **does not exist**; no patch is required.
* **The mirror is written by firmware, and it is partial.** A firmware routine at
ROM `0x050E` performs a CP/M-style page-zero setup: it copies the low 64-byte
block `ROM[0x0000-0x003F]` (reset jump, OS-call entry, and the NSC800 restart
vectors including RSTA at `0x003C`) into the low `0x0000-0x003F` of **every**
paged-RAM bank. Because the copy is exactly **64 bytes**, RSTA's vector at
`0x003C` is **inside** the mirror (reads correct in any bank, no override needed)
while NMI's vector at `0x0066` is **outside** it (\~38 bytes past the edge, never
mirrored). That partial extent is the single fact that reconciles section 4.1 with section 4.2:
the NMI vector needs MAME's ROM-override at `0x0066` precisely because the
firmware's page-zero mirror stops at `0x003F` and does not reach it, whereas the
RSTA vector needs no override because the mirror covers it.

### 4.3 Idle state

At the plain BASIC prompt the **NMI** path (TX-gated) and the tape-mode
`0x0038`/`FAC6` trampoline are dormant, but the **NSC800 RSTA interrupt (via**
**0x003C -> FDFB) is active** at \~61 Hz -- so there *is* a periodic interrupt at
idle, and it **drives the keyboard scan**: the active RSTA ISR (`TIMER_AB_ISR`)
strobes the key matrix each tick and fills the key buffer, which the foreground
`INKEY$`/`INPUT` loops then poll. The keyboard is interrupt-scanned, not
foreground-polled (confirmed by tracing the ISR).

- - -

## 5\. Coverage \-\- at a glance

### 5.1 [OK] -- verified working under MAME

* ROM byte reads + cold-boot to BASIC prompt
* V24 serial TX bit-bang chain
* Timer 0 NMI countdown during V24 TX
* NSC810 Timer 0 baud accuracy (all 11 standard rates 75-9600, <=0.08% at 4 MHz)
* Port 81H V24 TX bit polarity
* Port 42H/43H real-time-clock reads
* BASIC interpreter core (keyword dispatch, token fetch, expression eval,
FOR/NEXT, IF/THEN, GOTO/GOSUB/RETURN, ON...GOTO)
* Character output cluster + LCD via PRINT path + direct port writes
* HD61830 LCD: PRINT, PSET/LINE, direct `OUT` to the display port,
machine-code blasting to the display ports
* Keyboard input chain (matrix scan -> circular buffer -> INKEY$)
* SCREEN statement (mode change + inverse-video)
* CALL to RAM-resident machine code + POKE/PEEK/VARPTR
* Floating-point arithmetic + transcendentals (SIN/COS/ABS ...)
* String routines (CHR$/ASC/LEN/MID$/LEFT$/RIGHT$/STR$)
* RAM-disk file I/O + program chaining (`RUN "filename"`)
* SYSTEM (return to the OS REPL)
* Paged-RAM font-overlay loading -- byte-perfect vs real Hunter
* Paged-RAM dispatch-overlay source bytes + bank-switch read path --
byte-perfect vs real Hunter
* Bank-1 paged-RAM mode + page-state shadows during normal BASIC --
byte-perfect vs real Hunter
* Paged-RAM PEEK read-back at the E000-EFFF window

### 5.2 [PARTIAL]

* **SOUND statement** \-\- protocol works \(verified by a game and a Morse program\);
fine-grained timing shows minor margin clipping under MAME.
* **DSR hardware handshaking** -- *fixed* (FIX-14, verified 2026-06-18). The driver had
read the DSR line non-inverted, so with the rs232 port's unconnected default presenting
DSR as asserted, the firmware's pre-transmit DSR wait would have busy-looped forever,
though it stayed **latent** (no verified program enables DSR handshaking, so nothing
reached the wait). The one-line fix reads DSR inverted, matching the Hunter's RS-232
control-input inversion; verified in-emulator on the release build (the default line now
reads DSR "ready" so transmit proceeds; a peer that de-asserts DSR correctly makes it
wait), with no HCOM/TERM regression. Real-hardware polarity is strongly implied but not
schematic-confirmed. CTS handshaking (used by HCOM) is unaffected.

### 5.3 [GAP]

* **None observed.** The previously-suspected interrupt-vector bank-override
gap was resolved by direct observation (every vector fetch reads correct ROM
bytes -- see section 4.2). No ROM-derived hardware-contract gap was found in any
program tested -- a result bounded by coverage, not a guarantee none exist in the
untested paths listed in section 5.4.

### 5.4 [UNKNOWN] -- untested, not known defects

* Periodic NMI / RSTA activity outside the V24-TX and tape contexts (no firmware
path exercises these at idle; both are gated by construction)
* Bank-1 RAM-mode foreground reads from arbitrary RAM banks (the boot LDIR
mirror at E000-EFFF is the one validated case; other banks not tested)

- - -

## 6\. Validated parity outcomes

Each probe captured real-Hunter ground truth and the same measurement under
MAME, then compared the byte-level outputs.

| Probe | What it measured | Result |
| ----- | ---------------- | ------ |
| Paged-RAM PEEK probe | Font-overlay state + window bytes at E72A/E740/EC86; page-state shadows | **Byte-perfect parity.** Validates overlay-load mechanism, paged-RAM shadows, PEEK read-back. |
| Dispatch-overlay probe | Dispatch-overlay source bytes via a bank-switching machine-code read | **Byte-perfect parity.** Validates bank switch to ROM + ROM byte content + dispatch-overlay load. |
| NMI tick-rate probe | Timer A NMI ticks/sec at idle / armed / no-arm | **Byte-perfect parity** at all three states (idle 0, armed \~61 Hz). Confirms TX-gated-by-construction. |
| IM 1 chain probe | Trampoline state at idle + software call chain through it | **Byte-perfect parity.** Confirms the conditional install + indirection works in MAME. |
| Interrupt-vector watch | Which vector addresses the CPU fetches during int-ack, and bytes + bank state | **Active vector = 0x003C (`c3 fb fd`), not 0x0038; NMI 0x0066 = `c3 14 f8`. RSTA armed at boot, \~61 Hz -- active, not dormant.** |
| RSTA forced-window test | Whether the RSTA vector fetch reads ROM or RAM garbage when RSTA fires *inside* a held paged-RAM window | **Vector fetch read `c3 fb fd` (correct ROM) and CPU jumped to the ISR -- even in paged-RAM mode. Mechanism: the paged-RAM bank mirrors the low ROM vectors. Gap closed by construction; no patch.** |
| NMI-vs-RSTA mirror probe | Per-vector POKE/PEEK in paged-RAM mode: is each slot RAM-backed (firmware mirror) or shadow-served? | **Partial mirror confirmed on silicon.** `0x003C` reads `195 251 253` and is poke-transparent on both platforms (firmware mirror = plain RAM). `0x0066` differs: real Hunter shows live RAM (`32 32 0`, poke-transparent) -- no vector copy there; MAME shows ROM (`195 20 248`, poke-opaque) via the read-shadow. Confirms the mirror covers `0x003C` not `0x0066`. |

**Net effect:** across the probes above, the paged-RAM, overlay, bank-switch,
interrupt-arming, and interrupt-vector-fetch contracts all matched real hardware.
Every NMI and RSTA vector fetch measured read correct ROM bytes.

- - -

## 7\. Open items

**No ROM-derived hardware-contract gaps were found across the programs and probes
tested.** That is bounded by coverage, not a guarantee none exist -- untested paths
remain (see section 5.4).

Residual non-gap notes:

* Instruction-fetch *breakpoint* visibility in the MAME debugger (distinct from
read-watchpoints, which are confirmed working) is a debugger-tooling detail,
not an emulation defect.
* The [UNKNOWN] items in section 5.4 are untested-but-unexercised paths, not known
problems.

- - -

*This is a point-in-time release summary. It is intentionally self-contained;*
*the underlying ROM disassembly, per-probe validation records, and development*
*history are being maintained separately.*