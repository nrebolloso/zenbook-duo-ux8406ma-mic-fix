#!/bin/bash
# Remove the snd-hda-codec-alc269-zenbookduo DKMS module and undo the install.
set -euo pipefail

PKG_NAME=snd-hda-codec-alc269-zenbookduo
PKG_VERSION=1.0
PKG_DEST="/usr/src/${PKG_NAME}-${PKG_VERSION}"

if [ "$(id -u)" != "0" ]; then
    echo "Run with sudo." >&2
    exit 1
fi

echo "==> Unregistering from DKMS (and removing built modules)"
dkms remove "${PKG_NAME}/${PKG_VERSION}" --all 2>/dev/null || true

echo "==> Removing source from /usr/src/"
rm -rf "$PKG_DEST"

echo "==> Updating initramfs"
update-initramfs -u

echo
echo "==> DONE. The headset mic will stop working again after the next reboot."
echo "    The kernel will fall back to its in-tree (unpatched) snd-hda-codec-alc269."
