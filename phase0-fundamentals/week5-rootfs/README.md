# Week 5 — Root Filesystem: Reaching a Shell

**Goal:** build a minimal rootfs from scratch and boot into my own shell —
closing the boot chain built piece by piece in weeks 2-4.

## What I did
- Built BusyBox statically for aarch64
- Assembled a minimal rootfs tree by hand (bin, proc, sys, dev, etc, init)
- Wrote an /init that mounts procfs and sysfs, then execs a shell
- Packed it as cpio.gz, served over TFTP, booted with all three booti arguments

## Key takeaways

**A minimal rootfs needs two things:** a filesystem to mount as /, and an
executable to run as PID 1.

**BusyBox uses symlinks** so hundreds of commands share one binary. It picks
which command to act as by reading argv[0] — the name it was invoked under.

**Static linking** means the rootfs needs exactly one file to work — no libc
version matching, no runtime "not found" errors.

**The init script must `exec` the shell**, not call it. exec replaces the process
so the shell becomes PID 1. Otherwise the script stays PID 1, and when the shell
exits the script finishes, PID 1 dies, and the kernel panics. PID 1 may not exit.

**/proc and /sys must exist but stay empty** — they are mount points. Virtual
filesystems get mounted on top; anything left inside is hidden, not deleted.
cat /proc/cpuinfo asks the kernel, it does not read from disk.

**rdinit= for initramfs, init= for a real rootfs.** Easy to mix up.

**Real products use initramfs** to break a chicken-and-egg problem: mounting the
real rootfs needs a storage driver that may itself live in the rootfs.

## Two problems worth remembering

**BusyBox build failed on networking/tc.c** (TCA_CBQ_* undeclared) — old software
against new kernel headers, a recurring embedded pattern. Fix: disable the applet
you don't need.

**"Wrong Ramdisk Image Format"** — a raw .cpio.gz has no header describing its
size, unlike the kernel image and DTB which are self-describing. U-Boot must be
told: `booti <kernel> <initrd>:<size> <dtb>`, or use `${filesize}`.

## Observations

    ps  ->  /bin/sh is PID 1, proving exec worked
    ls -la /bin/ls  ->  symlink to busybox
    mount  ->  only rootfs, proc, sysfs — exactly what /init mounted

Of ~50 processes, only two are mine; the rest in square brackets are kernel
threads — a clear picture of the kernel/user boundary.

## Sizes

| Component | Size |
|-----------|------|
| u-boot.bin | ~1 MB |
| busybox (static) | 2.2 MB |
| initramfs.cpio.gz | 1.2 MB |
| Image (kernel) | 49 MB |

The whole userspace is 2.2 MB while the kernel is 49 MB, because defconfig ships
drivers for every board. Kernel to shell: 0.68 seconds.

## Commands

    # busybox
    export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
    make defconfig
    make menuconfig   # Build Options -> [*] static ; Networking -> [ ] tc
    make -j$(nproc)
    make CONFIG_PREFIX=../rootfs install

    # rootfs
    mkdir -p proc sys dev etc
    chmod +x init
    find . | cpio -H newc -o | gzip > ../initramfs.cpio.gz

    # u-boot
    tftp 0x40400000 Image
    tftp 0x44000000 initramfs.cpio.gz
    setenv bootargs 'console=ttyAMA0 rdinit=/init'
    booti 0x40400000 0x44000000:${filesize} 0x40000000

## The chain is now closed

power on -> U-Boot (w2) -> network load (w3) -> kernel (w4) -> rootfs (w5) -> shell

Every link built by hand. Weeks 6-8 automate it with Buildroot.
