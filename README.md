# coreboot-qa

FirmwareCI test definitions for QA-testing coreboot firmware on real and
emulated devices.

## What this repository contains

- `.firmwareci/` — the FirmwareCI project that drives the tests:
  - **workflows** — the test suites (e.g. Prodrive Hermes, QEMU), each a set of
    checks run against a device. The checks live in each workflow's `tests/`
    directory.
  - **DUTs** — the devices under test the workflows run on (real hardware and
    QEMU boards), with their pre-/post-stage setup.
  - **storage** — the OS images the tests boot.
- `images/` + `Taskfile.yaml` — build the QEMU disk images used by the emulated
  targets (`task build-images`).
- `ci/jenkins.sh` is the build step of the coreboot Jenkins job. It builds the
  roms and submits them to FirmwareCI.

## How testing works

1. For every patchset uploaded to Gerrit, Jenkins builds one `coreboot.rom`
   per target with `ci/jenkins.sh`.
2. CI submits that rom to FirmwareCI, referencing this repository as the
   project (`FWCI_PROJECT_LINK`).
3. FirmwareCI flashes/boots the rom on the matching DUT — real hardware
   (Prodrive Hermes) or an emulated board (QEMU) — and runs the workflow's
   checks: boot, serial output, coreboot tables (cbmem), PCI, SMBIOS,
   warm-reboot, and so on.
4. Results are reported back per check to gerrit patchsets.

To add a target, add a DUT and a workflow under `.firmwareci/`, put its
checks in the workflow's `tests/` directory and build its rom in
`ci/jenkins.sh`.

## CI targets

| Workflow | coreboot config | Notes |
|---|---|---|
| QEMU-Q35 | `config.emulation_qemu_x86_q35_smm_tseg` | SeaBIOS payload, `CONFIG_SEABIOS_HARDWARE_IRQ=n` |
| Prodrive-Hermes | `config.prodrive_hermes.edk2` from the private blobs repo | edk2 payload |
| QEMU-AArch64 | `config.emulation_qemu_aarch64_fit_support_timestamps` | payload is `payloads/aarch64-hello/hello.elf` from `main` |

## coreboot source

coreboot is developed upstream on Gerrit:

<https://review.coreboot.org>
