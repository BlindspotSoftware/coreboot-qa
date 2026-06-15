# aarch64-hello

Minimal coreboot payload for the qemu-aarch64 virt board. Writes
`FWCI-PAYLOAD-HELLO` to the PL011 UART (0x09000000), then `wfi`s forever.

Used by the `QEMU-AArch64` smoke workflow to prove the full
bootblock -> romstage -> ramstage -> payload chain works without dragging
in u-boot/edk2/LinuxBoot.

## Build the payload

Requires `gcc-aarch64-linux-gnu` + `binutils-aarch64-linux-gnu`:

```sh
sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
./build.sh
```

Output: `hello.elf`.

## Bake into a coreboot rom

Needs `cbfstool` (the firmwareci coreboot tree builds one under
`build/cbfstool/cbfstool`):

```sh
ROM=/path/to/coreboot-aarch64.rom ./build.sh inject
```

`add-payload` converts the ELF to selfboot segments. Verify with
`cbfstool $ROM print`; `fallback/payload` should now exist.

## Upload to firmwareci storage

The smoke workflow references the rom as
`[[storage.CorebootAarch64Hello]]/coreboot.rom`. Upload the patched rom
under that storage name (via the fwci CLI or web frontend); see
`.firmwareci/storage/CorebootAarch64Hello/storage.yaml` for the
declaration.

## Layout details

- Load + entry address: `0x40100000`. Sits inside the first RAM range
  coreboot reports on the qemu virt aarch64 board
  (`0x40000000-0x6001ffff`), so no overlap with bootblock/romstage/
  ramstage allocations.
- UART: PL011 at `0x09000000`. Writing the data register sends a byte;
  no init required because coreboot's ramstage has already brought the
  UART up by the time the payload runs.
