# Coreboot QA Test Images

Both systems build on [firmwareci-base-image](https://github.com/BlindspotSoftware/firmwareci-base-image).

## QEMU

Build: `make` or `nix build .#qemu`

Output: `qemu/nixos.img`, uploaded to FirmwareCI as the `OSImage` storage.

## Prodrive Hermes

The board boots NixOS from its own disk. `nixosConfigurations.hermes` is that
system. Power the board on, lock it in FirmwareCI, then from the repo root:

```sh
task deploy-hermes
```

It becomes the default boot entry for the next boot; the previous generation
stays in the boot menu.
