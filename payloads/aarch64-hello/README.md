# aarch64-hello

Minimal coreboot payload for the qemu-aarch64 virt board. Writes
`FWCI-PAYLOAD-HELLO` to the PL011 UART (0x09000000), then `wfi`s forever.

Used by the `QEMU-AArch64` smoke workflow to prove the full
bootblock -> romstage -> ramstage -> payload chain works without dragging
in u-boot/edk2/LinuxBoot.

## Build the payload

Needs docker:

```sh
task build-hello-payload
```

Output: `hello.elf`.

## Bake into a coreboot rom

CI pulls `hello.elf` from `main` and builds it in:

```text
# CONFIG_PAYLOAD_NONE is not set
CONFIG_PAYLOAD_ELF=y
CONFIG_PAYLOAD_FILE="hello.elf"
```

Changes to `hello.elf` apply once they're on `main`.

## Layout details

- Load + entry address: `0x40100000`. Sits inside the first RAM range
  coreboot reports on the qemu virt aarch64 board
  (`0x40000000-0x6001ffff`), so no overlap with bootblock/romstage/
  ramstage allocations.
- UART: PL011 at `0x09000000`. Writing the data register sends a byte;
  no init required because coreboot's ramstage has already brought the
  UART up by the time the payload runs.
