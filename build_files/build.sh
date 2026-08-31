#!/usr/bin/env bash
set -euo pipefail

echo "=== Starte MediaTek Bluetooth Fix Build ==="

# 1. Pakete installieren (ohne patch)
dnf5 install -y kernel-devel gcc make xz curl

# 2. Bazzite-Kernelversion ermitteln
TARGET_KVER=$(ls /usr/lib/modules | head -n 1)
BASE_KVER=$(echo "${TARGET_KVER}" | cut -d'-' -f1)
MAJOR_VER=$(echo "${BASE_KVER}" | cut -d'.' -f1)

echo "Bazzite Target-Kernel: ${TARGET_KVER}"

# 3. Kernel-Sourcen laden
cd /tmp
curl -sSL "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VER}.x/linux-${BASE_KVER}.tar.xz" | tar -xJ
cd "linux-${BASE_KVER}"

# 4. USB-ID direkt per sed am Anfang der Tabelle einfügen
echo "Füge USB-ID 0489:e13a direkt in btusb.c ein..."
sed -i '/static const struct usb_device_id btusb_table\[\] = {/a \  { USB_DEVICE(0x0489, 0xe13a), .driver_info = BTUSB_MEDIATEK },' drivers/bluetooth/btusb.c

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
dnf5 remove -y kernel-devel gcc make xz curl
dnf5 clean all

echo "=== Build erfolgreich abgeschlossen! ==="
