#!/usr/bin/env bash
set -euo pipefail

echo "=== Starte MediaTek Bluetooth Fix Build ==="

# 1. Pakete mit dnf5 installieren
dnf5 install -y kernel-devel gcc make patch xz curl

# 2. Installierte Bazzite-Kernelversion ermitteln
TARGET_KVER=$(ls /usr/lib/modules | head -n 1)
BASE_KVER=$(echo "${TARGET_KVER}" | cut -d'-' -f1)
MAJOR_VER=$(echo "${BASE_KVER}" | cut -d'.' -f1)

echo "Bazzite Target-Kernel: ${TARGET_KVER}"

# 3. Kernel-Sourcen laden
cd /tmp
curl -sSL "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VER}.x/linux-${BASE_KVER}.tar.xz" | tar -xJ
cd "linux-${BASE_KVER}"

# 4. Patch-Datei suchen & anwenden (-p1 statt -p3)
PATCH_PATH="/ctx/mediatek_bt.patch"
if [ ! -f "$PATCH_PATH" ]; then
    PATCH_PATH="/ctx/build_files/mediatek_bt.patch"
fi

echo "Wende Patch an aus: ${PATCH_PATH}"
patch -p1 < "${PATCH_PATH}"

# 5. btusb-Modul kompilieren
cd drivers/bluetooth
echo "obj-m := btusb.o" > Makefile

BUILD_DIR=$(ls -d /usr/src/kernels/* | head -n 1)
make -C "${BUILD_DIR}" M="$(pwd)" modules

# 6. Gepatchtes Modul ins Image einpflegen
EXTRA_DIR="/usr/lib/modules/${TARGET_KVER}/extra"
mkdir -p "${EXTRA_DIR}"
cp btusb.ko "${EXTRA_DIR}/"
depmod -a -b /usr "${TARGET_KVER}"

# 7. Aufräumen
dnf5 remove -y kernel-devel gcc make patch xz curl
dnf5 clean all

echo "=== Build erfolgreich abgeschlossen! ==="
