#!/usr/bin/env bash
# Build a static aarch64 hello-world coreboot payload and bake it into a
# coreboot.rom CBFS as fallback/payload. Output: hello.elf and an
# in-place patched rom written to $OUT_ROM.
#
# Requires:
#   - aarch64-linux-gnu-gcc, aarch64-linux-gnu-ld, aarch64-linux-gnu-objcopy
#     (apt: gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu)
#   - cbfstool on PATH or pointed at via $CBFSTOOL
#
# Usage:
#   ./build.sh                       # builds hello.elf only
#   ROM=/path/to/coreboot.rom ./build.sh inject
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CC=${CC:-aarch64-linux-gnu-gcc}
LD=${LD:-aarch64-linux-gnu-ld}
CBFSTOOL=${CBFSTOOL:-cbfstool}

"$CC" -nostdlib -ffreestanding -c "$HERE/hello.S" -o "$HERE/hello.o"
"$LD" -T "$HERE/hello.ld" -nostdlib --no-warn-rwx-segments \
    -o "$HERE/hello.elf" "$HERE/hello.o"

echo "Built: $HERE/hello.elf"

if [[ "${1:-}" == "inject" ]]; then
    : "${ROM:?Set ROM=/path/to/coreboot.rom}"
    # Remove pre-existing payload entry if any (idempotent re-injection).
    "$CBFSTOOL" "$ROM" remove -n fallback/payload 2>/dev/null || true
    "$CBFSTOOL" "$ROM" add-payload \
        -f "$HERE/hello.elf" \
        -n fallback/payload \
        -c lzma
    echo "Injected into: $ROM"
    "$CBFSTOOL" "$ROM" print | grep -E "fallback/payload|Name" || true
fi
