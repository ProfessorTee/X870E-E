#!/usr/bin/env bash
set -euo pipefail

echo "Starte Build für MediaTek Bluetooth Fix..."

# 1. Bazzite Kernel-Version auslesen (statt den Kernel des GitHub-Servers zu nutzen)
TARGET_KVER=$(ls /lib/modules | head -n 1)
KVER_MAJOR=$(echo $TARGET_KVER | cut -d'.' -f1)
KVER_MINOR=$(echo $TARGET_KVER | cut -d'.' -f2)
DL_KVER="${KVER_MAJOR}.${KVER_MINOR}"

echo "Baue Modul für Bazzite-Kernel: $TARGET_KVER"

# 2. Build-Tools für das Kompilieren installieren
dnf install -y kernel-devel gcc make patch xz

# 3. Passende Kernel-Sourcen von kernel.org laden
cd /tmp
curl -sL "https://cdn.kernel.org/pub/linux/kernel/v${KVER_MAJOR}.x/linux-${DL_KVER}.tar.xz" | tar -xJ
cd linux-${DL_KVER}/drivers/bluetooth

# 4. Patch anwenden (Die Dateien aus build_files liegen durch das Containerfile in /ctx)
patch -p3 < /ctx/mediatek_bt.patch

# 5. Modul gegen die Bazzite-Kernel-Header kompilieren
echo "obj-m := btusb.o" > Makefile
make -C /usr/src/kernels/${TARGET_KVER} M=$(pwd) modules

# 6. Fertiges Modul in das System-Image integrieren
TARGET_DIR="/usr/lib/modules/${TARGET_KVER}/extra"
mkdir -p "${TARGET_DIR}"
cp btusb.ko "${TARGET_DIR}/"
depmod -a -b /usr ${TARGET_KVER}

# 7. Aufräumen, um das Image klein zu halten
dnf remove -y kernel-devel gcc make patch xz
dnf clean all

echo "Bluetooth Fix erfolgreich integriert!"
