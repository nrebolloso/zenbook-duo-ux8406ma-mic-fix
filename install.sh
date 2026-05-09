#!/bin/bash
# Install the snd-hda-codec-alc269-zenbookduo DKMS module on Ubuntu / Linux Mint.
# Patches the in-tree ALC269 codec driver to enable the headset mic on the
# ASUS Zenbook Duo UX8406MA (PCI SSID 1043:1c43).
set -euo pipefail

PKG_NAME=snd-hda-codec-alc269-zenbookduo
PKG_VERSION=1.0
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PKG_SRC="$SCRIPT_DIR/${PKG_NAME}-${PKG_VERSION}"
PKG_DEST="/usr/src/${PKG_NAME}-${PKG_VERSION}"

if [ "$(id -u)" != "0" ]; then
    echo "Run with sudo." >&2
    exit 1
fi

if [ ! -d "$PKG_SRC" ]; then
    echo "Cannot find $PKG_SRC. Run this script from the repo root." >&2
    exit 1
fi

# Sanity check hardware
if ! lspci -nn 2>/dev/null | grep -qi '1043:1c43'; then
    echo "WARNING: PCI ID 1043:1c43 (ASUS Zenbook Duo UX8406MA) not found on this machine."
    echo "         The patch will install but only takes effect on that device."
    echo "         Press Enter to continue, Ctrl-C to abort."
    read -r
fi

# Build prerequisites
missing=""
for pkg in dkms build-essential "linux-headers-$(uname -r)"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        missing="$missing $pkg"
    fi
done
if [ -n "$missing" ]; then
    echo "==> Installing build prerequisites:$missing"
    apt-get install -y $missing
fi

echo "==> Copying DKMS package to $PKG_DEST"
rm -rf "$PKG_DEST"
cp -a "$PKG_SRC" "$PKG_DEST"

echo "==> (Re-)registering with DKMS"
dkms remove "${PKG_NAME}/${PKG_VERSION}" --all 2>/dev/null || true
dkms add "${PKG_NAME}/${PKG_VERSION}"

echo "==> Building for current kernel ($(uname -r))"
dkms build "${PKG_NAME}/${PKG_VERSION}"

echo "==> Installing module to /lib/modules/$(uname -r)/updates/dkms/"
dkms install "${PKG_NAME}/${PKG_VERSION}"

# If a prior legacy-HDA workaround is in GRUB, undo it so SOF (and the CS35L41
# speaker DSP firmware) comes back.
if grep -q 'snd_intel_dspcfg.dsp_driver=1' /etc/default/grub 2>/dev/null; then
    echo "==> Removing snd_intel_dspcfg.dsp_driver=1 from /etc/default/grub"
    sed -i 's/ *snd_intel_dspcfg\.dsp_driver=1//' /etc/default/grub
    update-grub
fi

echo "==> Updating initramfs (codec module loads early)"
update-initramfs -u

echo
echo "==> DONE. Reboot to activate."
echo
echo "After reboot you should see:"
echo "    - sound card: sof-hda-dsp (SOF active)"
echo "    - two PipeWire input sources: built-in DMIC array AND headset analog mic"
echo "    - Cirrus CS35L41 speaker DSP firmware loaded (in dmesg)"
echo
dkms status "${PKG_NAME}/${PKG_VERSION}"
