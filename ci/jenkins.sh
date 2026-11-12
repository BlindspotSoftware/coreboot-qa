#!/bin/bash
# Build step of the coreboot Jenkins job. Jenkins checks out every patchset
# uploaded to review.coreboot.org and runs this script in that checkout. It
# builds one rom per coreboot-qa workflow and submits it to FirmwareCI.
#
# Needs from Jenkins: the GERRIT_* variables of the Gerrit Trigger plugin,
# FWCI_TOKEN (or FWCI_EMAIL and FWCI_PASSWORD) and BLOBS_SSH_KEY, a key with
# read access to the private blobs repo for the Hermes config.
set -e
trap 'rm -rf .git/hooks' EXIT

echo 500 2>/dev/null > /proc/self/oom_score_adj || true

git config --global --add safe.directory "*"
rm -rf .git/hooks

# submodules
git submodule init || true
git submodule update --checkout || (rm -rf .git/modules; git submodule deinit --all -f; git submodule update --checkout --init)
git diff | grep -q "Subproject\|submodule" && (rm -rf .git/modules; git submodule deinit --all -f; git submodule update --checkout --init)
git submodule foreach 'test -f go.mod && go mod download || true'

EXP=$(grep -oP '^GCC_VERSION=\K[0-9.]+$' util/crossgcc/buildgcc)

jobs_for() {
    local per=$1 mem cpus n
    mem=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    cpus=$(nproc)
    n=$(( mem / per ))
    [ "$n" -lt 1 ] && n=1
    [ "$n" -gt "$cpus" ] && n="$cpus"
    echo "$n"
}

# build the toolchain only when its version differs. Tarballs are cached in
# $HOME (survives the per-build workspace wipe) and restored before building, so
# the flaky GNU mirror (ftpmirror.gnu.org, seen failing on mpc) only has to fetch
# each tarball successfully once. Verified tarballs are saved back after every
# attempt.
crossgcc() {
    local arch=$1 gcc=$2 act ok cpus cache="$HOME/.cache/coreboot-crossgcc-tarballs"
    act=$(util/crossgcc/xgcc/bin/"$gcc" --version 2>/dev/null | head -n1 | grep -oP '[0-9.]+$' || true)
    [ "$EXP" = "$act" ] && return 0

    mkdir -p "$cache" util/crossgcc/tarballs
    cp -an "$cache"/. util/crossgcc/tarballs/ 2>/dev/null || true

    ulimit -t 7200
    for attempt in 1 2 3 4; do
        ok=
        cpus=$(( $(jobs_for 2048) / attempt )); [ "$cpus" -lt 1 ] && cpus=1
        echo "crossgcc-$arch attempt $attempt with CPUS=$cpus" >&2
        if nice -n 20 make crossgcc-"$arch" CPUS="$cpus"; then ok=1; fi
        cp -an util/crossgcc/tarballs/. "$cache"/ 2>/dev/null || true
        [ -n "$ok" ] && return 0
        if [ "$attempt" -eq 4 ]; then
            echo "crossgcc-$arch failed after $attempt attempts" >&2
            exit 1
        fi
        echo "crossgcc-$arch attempt $attempt failed; retrying in 30s" >&2
        find util/crossgcc/tarballs -maxdepth 1 -empty -delete 2>/dev/null || true
        sleep 30
    done
}

# build the coreboot rom from the in-place .config, post it to the FirmwareCI
# workflow, and archive the rom.
build_submit() {
    local workflow=$1 artifact=$2
    ulimit -t 3600 -f 2560000
    make olddefconfig
    nice -n 20 make -j"$(jobs_for 768)" BUILD_TIMELESS=1

    FWCI_WORKFLOW_NAME="$workflow" ./job-request-script.sh

    mkdir -p artifacts
    cp build/coreboot.rom "artifacts/$artifact"
}

crossgcc i386 i386-elf-gcc
crossgcc aarch64 aarch64-elf-gcc

export CCACHE_DIR=$HOME/.ccache
export CCACHE_MAXSIZE=10G
mkdir -p "$CCACHE_DIR"
ccache -z || true

# -f aborts on HTTP error instead of saving the 404 page as the script.
curl -fsSL -o job-request-script.sh https://raw.githubusercontent.com/BlindspotSoftware/gerrit-integration/main/job-request-script.sh
chmod +x job-request-script.sh
export FWCI_PROJECT_LINK=github.com/BlindspotSoftware/coreboot-qa
export BINARIES="Binary=build/coreboot.rom"

# --- QEMU x86 (q35) ---
make clean
cp configs/config.emulation_qemu_x86_q35_smm_tseg ./.config
echo 'CONFIG_SEABIOS_HARDWARE_IRQ=n' >>./.config
build_submit QEMU-Q35 coreboot-qemu-q35.rom

# --- Prodrive Hermes ---
make clean
rm -rf 3rdparty/blobs
GIT_SSH_COMMAND="ssh -i $BLOBS_SSH_KEY -o StrictHostKeyChecking=no" \
    git clone git@github.com:BlindspotSoftware/blobs.git 3rdparty/blobs
cp 3rdparty/blobs/configs/firmwareci/config.prodrive_hermes.edk2 ./.config
# coreboot die()s on bar-less generic devices (find_resource(BAR0) with no BAR):
# cnvi_wifi (absent) and uart2 (hidden generic child). Reduce to plain forms.
DT=src/mainboard/prodrive/hermes/devicetree.cb
sed -i '/device ref cnvi_wifi on/,/^\t\tend$/c\\t\tdevice ref cnvi_wifi off end' "$DT"
sed -i '/device ref uart2 hidden #/,/^\t\tend$/c\\t\tdevice ref uart2 hidden end # in ACPI mode' "$DT"
if grep -qE 'device generic 0 (on|hidden)' "$DT"; then
    echo "PATCH FAILED: bar-less generic device still present" >&2; grep -n "device generic 0" "$DT" >&2; exit 1
fi
echo "PATCH OK: cnvi_wifi + uart2 generic devices removed"
build_submit Prodrive-Hermes coreboot-prodrive-hermes.rom

# --- QEMU aarch64 ---
make clean
cp configs/config.emulation_qemu_aarch64_fit_support_timestamps ./.config
# arm64 defaults to PAYLOAD_NONE; the QEMU-AArch64 smoke test expects the
# hello payload's banner on the UART.
curl -fsSL -o hello.elf https://raw.githubusercontent.com/BlindspotSoftware/coreboot-qa/main/payloads/aarch64-hello/hello.elf
echo '# CONFIG_PAYLOAD_NONE is not set' >>./.config
echo 'CONFIG_PAYLOAD_ELF=y' >>./.config
echo 'CONFIG_PAYLOAD_FILE="hello.elf"' >>./.config
build_submit QEMU-AArch64 coreboot-qemu-aarch64.rom

ccache -s || true
ccache -c || true
