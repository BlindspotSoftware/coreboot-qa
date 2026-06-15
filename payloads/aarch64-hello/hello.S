/*
 * Minimal aarch64 coreboot payload for the qemu-system-aarch64 -M virt board.
 * Writes a banner to the PL011 UART at 0x09000000, then halts in a WFI loop.
 *
 * Linked to load + run at 0x40100000 (well inside the first RAM region
 * coreboot reports on the qemu virt aarch64 board: 0x40000000-0x6001ffff).
 */

#define PL011_DR 0x09000000

    .section .text.start,"ax"
    .global _start
_start:
    ldr     x0, =PL011_DR
    adr     x1, msg
1:  ldrb    w2, [x1], #1
    cbz     w2, 2f
    strb    w2, [x0]
    b       1b
2:  wfi
    b       2b

    .section .rodata
msg:
    .ascii  "FWCI-PAYLOAD-HELLO\n"
    .byte   0
