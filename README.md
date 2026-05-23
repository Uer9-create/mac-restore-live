# mac-restore-live

A custom Ubuntu 22.04 live ISO for restoring macOS on Apple Silicon Macs.
Boot it from a Ventoy USB drive, download the IPSW, and run \`idevicerestore\` —
all without needing a working macOS installation.

## What's included

| Tool | Purpose |
|-----|--------|
| `idevicerestore` | Compiled from source — restores macOS via DFU/Recovery mode |
| `ipsw-downloader` | Interactive CLI to browse and download IPSW files from ipsw.me |
| `mac-restore` | Friendly wrapper around idevicerestore with safety prompts |
| Ubuntu 22.04 Desktop | Full GUI environment including Firefox for manual browsing |

## Requirements

- A second Mac or Linux PC to build the ISO (needs ~20 GB free disk space)
- A USB drive (32 GB+) with [Ventoy](https://www.ventoy.net) installed
- The target Mac in **DFU mode** or **Recovery mode**
- A USB-C cable (direct connection, avoid hubs)

## Build the ISO

> Run on any Ubuntu/Debian machine with `sudo` access.

```bash
# Install build dependencies
sudo apt install xorrso squashfs-tools wget curl python3

# Clone this repo
git clone https://github.com/Uer9-create/mac-restore-live.git
cd mac-restore-live

# Build (takes 20-40 min depending on your connection & CPU)
sudo ./build.sh
```

The output file `mac-restore-live.iso` will appear in the current directory.

## Copy to Ventoy USB

Just copy the ISO to the root of your Ventoy USB drive:

```bash
cp mac-restore-live.iso /media/youruser/Ventoy/
```

Then boot from the USB drive (hold Power on Apple Silicon to get boot picker).

## Using the live environment

1. **Boot** from the Ventoy USB and select `mac-restore-live.iso`
2. **Connect** your Mac via USB-C while it's in DFU/Recovery mode
3. **Download IPSW** — double-click `Download IPSW` on the desktop, or run:
   ```bash
   ipsw-downloader
   ```
4. **Restore** ℔ double-click `Mac Restore` on the desktop, or run:
   ```bash
   sudo mac-restore ~/Downloads/your-file.ipsw
   ```

## Putting your Mac into DFU mode (Apple Silicon)

1. Shut down the Mac completely
2. Hold the **Power button** for 10 seconds
3. Release, then hold **Power + Vol Down** for 3 seconds
4. The Mac will appear as a DFU device — no screen output is normal

## Credits

- [libimobiledevice/idevicerestore](https://github.com/libimobiledevice/idevicerestore)
- [ipsw.me](https://ipsw.me) for the firmware API
- [Ventoy](https://www.ventoy.net) for multiboot USB support
