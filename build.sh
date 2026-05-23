#!/usr/bin/env bash
# =============================================================================
# mac-restore-live/build.sh
# Builds a custom Ubuntu 22.04 live ISO with idevicerestore pre-compiled
# and an IPSW downloader. Output is Ventoy/UEFI compatible.
# =============================================================================
set -euo pipefail

UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-desktop-amd64.iso"
UBUNTU_ISO="ubuntu-22.04.5-desktop-amd64.iso"
WORK_DIR="$(pwd)/build_tmp"
MOUNT_DIR="$WORK_DIR/iso_mount"
EXTRACT_DIR="$WORK_DIR/iso_extract"
SQUASH_DIR="$WORK_DIR/squashfs_root"
OUTPUT_ISO="mac-restore-live.iso"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

require_root() { [ "$EUID" -eq 0 ] || error "Please run as root: sudo ./build.sh"; }
require_tools() {
  for t in xorriso unsquashfs mksquashfs wget curl python3; do
    command -v "$t" &>/dev/null || error "Missing tool: $t — run: sudo apt install xorriso squashfs-tools wget curl python3"
  done
}

download_iso() {
  if [ -f "$UBUNTU_ISO" ]; then
    info "ISO already present: $UBUNTU_ISO"
  else
    info "Downloading Ubuntu 22.04 Desktop ISO (~4.7GB)..."
    wget -c --progress=bar:force "$UBUNTU_ISO_URL" -O "$UBUNTU_ISO"
  fi
}

prepare_dirs() {
  info "Preparing work directories..."
  rm -rf "$WORK_DIR"
  mkdir -p "$MOUNT_DIR" "$EXTRACT_DIR" "$SQUASH_DIR"
}

mount_iso() {
  info "Mounting ISO..."
  mount -o loop,ro "$UBUNTU_ISO" "$MOUNT_DIR"
  rsync -a --exclude='casper/filesystem.squashfs' "$MOUNT_DIR/" "$EXTRACT_DIR/"
}

extract_squashfs() {
  info "Extracting squashfs (this takes a few minutes)..."
  unsquashfs -d "$SQUASH_DIR" "$MOUNT_DIR/casper/filesystem.squashfs"
}

setup_chroot() {
  info "Setting up chroot environment..."
  mount --bind /dev     "$SQUASH_DIR/dev"
  mount --bind /dev/pts "$SQUASH_DIR/dev/pts"
  mount --bind /proc    "$SQUASH_DIR/proc"
  mount --bind /sys     "$SQUASH_DIR/sys"
  cp /etc/resolv.conf   "$SQUASH_DIR/etc/resolv.conf"
}

install_software() {
  info "Installing packages and compiling idevicerestore inside chroot..."
  cp scripts/chroot-install.sh "$SQUASH_DIR/tmp/chroot-install.sh"
  chmod +x "$SQUASH_DIR/tmp/chroot-install.sh"
  chroot "$SQUASH_DIR" /tmp/chroot-install.sh
  rm "$SQUASH_DIR/tmp/chroot-install.sh"
}

overlay_files() {
  info "Copying overlay files..."
  cp overlay/usr/local/bin/mac-restore    "$SQUASH_DIR/usr/local/bin/mac-restore"
  cp overlay/usr/local/bin/ipsw-downloader "$SQUASH_DIR/usr/local/bin/ipsw-downloader"
  chmod +x "$SQUASH_DIR/usr/local/bin/mac-restore"
  chmod +x "$SQUASH_DIR/usr/local/bin/ipsw-downloader"
  mkdir -p "$SQUASH_DIR/home/ubuntu/Desktop"
  cp overlay/home/ubuntu/Desktop/Mac-Restore.desktop "$SQUASH_DIR/home/ubuntu/Desktop/"
  cp overlay/home/ubuntu/Desktop/IPSW-Downloader.desktop "$SQUASH_DIR/home/ubuntu/Desktop/"
  chmod +x "$SQUASH_DIR/home/ubuntu/Desktop/"*.desktop
}

teardown_chroot() {
  info "Unmounting chroot..."
  umount "$SQUASH_DIR/sys"    2>/dev/null || true
  umount "$SQUASH_DIR/proc"   2>/dev/null || true
  umount "$SQUASH_DIR/dev/pts" 2>/dev/null || true
  umount "$SQUASH_DIR/dev"    2>/dev/null || true
}

rebuild_squashfs() {
  info "Rebuilding squashfs (this takes several minutes)..."
  mksquashfs "$SQUASH_DIR" "$EXTRACT_DIR/casper/filesystem.squashfs" \
    -comp xz -b 1M -no-progress -noappend
  printf '%s' "$(du -sx --block-size=1 "$SQUASH_DIR" | cut -f1)" \
    > "$EXTRACT_DIR/casper/filesystem.size"
}

build_iso() {
  info "Building bootable ISO..."
  xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "Mac-Restore-Live" \
    -eltorito-boot boot/grub/bios.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e EFI/efi.img \
    -no-emul-boot \
    -append_partition 2 0xef "$EXTRACT_DIR/EFI/efi.img" \
    -output "$OUTPUT_ISO" \
    -graft-points \
    "$EXTRACT_DIR" \
    /boot/grub/bios.img="$EXTRACT_DIR/boot/grub/bios.img" 2>&1
  info "ISO built: $OUTPUT_ISO ($(du -sh "$OUTPUT_ISO" | cut -f1))"
}

cleanup() {
  info "Cleaning up..."
  umount "$MOUNT_DIR" 2>/dev/null || true
  teardown_chroot
}
trap cleanup EXIT

main() {
  require_root
  require_tools
  download_iso
  prepare_dirs
  mount_iso
  extract_squashfs
  setup_chroot
  install_software
  overlay_files
  teardown_chroot
  rebuild_squashfs
  umount "$MOUNT_DIR" 2>/dev/null || true
  build_iso
  info "Done! Copy $OUTPUT_ISO to your Ventoy USB drive."
}

main "$@"
