/*
 * Link the hello payload at 0x40100000 (RAM region reported by coreboot's
 * ramstage on the qemu virt aarch64 board). cbfstool add-payload converts
 * this ELF to selfboot segments; coreboot's bootblock-side loader then
 * copies PT_LOAD segments to their p_paddr and jumps to e_entry.
 */

ENTRY(_start)

SECTIONS
{
    . = 0x40100000;

    .text : {
        KEEP(*(.text.start))
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    /DISCARD/ : { *(.note* *.comment* *.eh_frame*) }
}
