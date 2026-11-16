# Coreboot QA Test Images

Both systems build on [firmwareci-base-image](https://github.com/BlindspotSoftware/firmwareci-base-image).

## QEMU

Build: `make` or `nix build .#qemu`

Output: `qemu/nixos.img`, uploaded to FirmwareCI as the `OSImage` storage.

## Prodrive Hermes

Build: `make hermes` or `nix build .#hermes`

Output: `hermes/nixos.img`, uploaded to FirmwareCI as the `HermesImage`
storage. The DUT's pre-stage plugs it into the board through the PiKVM's USB
drive.

To upload a new version, compress it, add it under a new name and point
`.firmwareci/storage/HermesImage/storage.yaml` at that name:

```sh
zstd -T0 hermes/nixos.img -o nixos.img.zst
fwci files add HermesImage_<version> nixos.img.zst
```
