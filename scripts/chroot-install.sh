#!/usr/bin/env bash
# Runs inside the Ubuntu 22.04 chroot to install packages and compile idevicerestore
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "[chroot] Enabling universe repo..."
apt-get install -y software-properties-common > /dev/null 2>&1 || true
add-apt-repository -y universe
apt-get update -q

echo "[chroot] Installing build dependencies..."
apt-get install -y \
  build-essential git autoconf automake libtool pkg-config \
  libssl-dev libcurl4-openssl-dev \
  libusb-1.0-0-dev libudev-dev \
  libzstd-dev libreadline-dev \
  libzip-dev \
  python3 python3-pip python3-requests \
  wget curl usbutils pciutils \
  zenity

echo "[chroot] Cloning and building libplist..."
cd /tmp
git clone --depth=1 https://github.com/libimobiledevice/libplist.git
cd libplist && ./autogen.sh --prefix=/usr/local --without-cython
make -j$(nproc) && make install && ldconfig
cd /tmp && rm -rf libplist

echo "[chroot] Building libimobiledevice-glue..."
git clone --depth=1 https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue && ./autogen.sh --prefix=/usr/local
make -j$(nproc) && make install && ldconfig
cd /tmp && rm -rf libimobiledevice-glue

echo "[chroot] Building libusbmuxd..."
git clone --depth=1 https://github.com/libimobiledevice/libusbmuxd.git
cd libusbmuxd && ./autogen.sh --prefix=/usr/local
make -j$(nproc) && make install && ldconfig
cd /tmp && rm -rf libusbmuxd

echo "[chroot] Building libimobiledevice..."
git clone --depth=1 https://github.com/libimobiledevice/libimobiledevice.git
cd libimobiledevice && ./autogen.sh --prefix=/usr/local --without-cython
make -j$(nproc) && make install && ldconfig
cd /tmp && rm -rf libimobiledevice

echo "[chroot] Building idevicerestore..."
git clone --depth=1 https://github.com/libimobiledevice/idevicerestore.git
cd idevicerestore && ./autogen.sh --prefix=/usr/local
make -j$(nproc) && make install && ldconfig
cd /tmp && rm -rf idevicerestore

echo "[chroot] Verifying idevicerestore..."
idevicerestore --version

echo "[chroot] Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/git* /root/.cache

echo "[chroot] All done."
