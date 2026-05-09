# zenbook-duo-ux8406ma-mic-fix

DKMS module that enables the 3.5 mm headset microphone on the **ASUS Zenbook
Duo (2024) UX8406MA** under Linux. Patches the in-tree `snd-hda-codec-alc269`
driver to add a missing pin override for the ALC294 codec's combo jack
(PCI SSID `1043:1c43`).

## Symptom

On Linux, the laptop's built-in DMIC array works but the 3.5 mm jack only
plays headphone audio while the headset microphone is silent. On Windows the same headset works fine.

`arecord -l` shows no analog capture device, and the kernel log reports
`autoconfig for ALC294: ... inputs:` with an empty inputs list. The ASUS
BIOS leaves all of the codec's analog input pins (`0x18`/`0x19`/`0x1a`)
configured as "unused" (`Pin Default 0x411111f0`). The existing
`1043:1c43` ALC294 quirk only attaches the Cirrus CS35L41 speaker amps;
no mic pin override is applied.

## Confirm your hardware

```
lspci -nn | grep -i 'audio'    # should list 1043:1c43
```

If you don't see `1043:1c43`, this fix isn't for you. The patch only
changes behaviour for that specific PCI subsystem ID.

## Install

```
git clone https://github.com/nrebolloso/zenbook-duo-ux8406ma-mic-fix
cd zenbook-duo-ux8406ma-mic-fix
sudo ./install.sh
sudo reboot
```

What `install.sh` does:

1. Installs `dkms`, `build-essential`, and matching `linux-headers` if
   missing.
2. Copies the bundled DKMS package source from
   `snd-hda-codec-alc269-zenbookduo-1.0/` to `/usr/src/`, then
   `dkms add/build/install`. The package's `dkms.conf` has
   `AUTOINSTALL=yes`, so the patched module rebuilds automatically on
   every kernel upgrade via `apt`'s DKMS hook.
3. If you previously tried the `snd_intel_dspcfg.dsp_driver=1` GRUB
   workaround, this script removes it so SOF (and the CS35L41 speaker
   DSP firmware) comes back.
4. Rebuilds initramfs.

The bundled `snd-hda-codec-alc269-zenbookduo-1.0/` directory contains
just the kernel headers and source files needed to compile
`snd-hda-codec-alc269.ko` out-of-tree (~500 KB, 28 files), all
unmodified Linux 6.17 source except for `alc269.c`, which has the patch
in `alc269.patch` already applied.

After reboot:

- `cat /proc/asound/cards` → `sof-hda-dsp`
- Two input sources in PipeWire: the built-in DMIC array **and** the
  headset analog mic
- CS35L41 speaker DSP firmware loaded (visible in `dmesg`)

## Uninstall

```
sudo ./uninstall.sh
sudo reboot
```

The kernel will fall back to the in-tree (unpatched) module after the
next reboot, and the headset mic will go silent again.

## What the patch does

`alc269.patch` adds three small changes to
`sound/hda/codecs/realtek/alc269.c`:

1. A new fixup enum value
   `ALC245_FIXUP_CS35L41_SPI_2_ASUS_UX8406_HEADSET_MIC`.
2. The fixup itself: sets pin `0x19` (the only input pin on this codec
   with mic-bias capability) to a headset-mic pin default `0x04a11020`,
   and chains to the existing `ALC245_FIXUP_CS35L41_SPI_2` so the
   speakers continue to work.
3. Switches the `SND_PCI_QUIRK(0x1043, 0x1c43, "ASUS UX8406MA", …)` row
   from `ALC245_FIXUP_CS35L41_SPI_2` to the new fixup.

The file path `sound/hda/codecs/realtek/alc269.c` is the post-6.17 layout
(the file was reorganised out of `sound/pci/hda/patch_realtek.c`). On
older kernels the same change applies to `patch_realtek.c`, but
`install.sh` does not handle that as it expects 6.17 or newer.

## Upstreaming

The patch in `alc269.patch` is formatted for submission to the ALSA
mailing list (`alsa-devel@alsa-project.org`, with `linux-kernel@vger`
and the HDA maintainers cc'd). If/when it lands upstream, the DKMS
module becomes redundant — `sudo ./uninstall.sh` and let the in-tree
driver take over.

## License

GPL-2.0. Required: the patch is a derivative of the GPL-2.0 Linux
kernel.
