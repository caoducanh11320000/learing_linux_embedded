#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo ""
echo "=========================================="
echo "  Rootfs cua ban da song!"
echo "=========================================="
echo ""
exec /bin/sh
