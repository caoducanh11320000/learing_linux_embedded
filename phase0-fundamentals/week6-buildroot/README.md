# Week 6 — Buildroot: Automating the Whole Chain

**Goal:** replace five weeks of manual commands with one config file and one
make — and understand what changes when a build system takes over.

## What I did
- Configured Buildroot with qemu_aarch64_virt_defconfig
- Built toolchain, kernel 6.18.7, BusyBox and an ext4 rootfs in a single run
- Booted the result and inspected the running system
- Extracted a minimal defconfig with make savedefconfig

## The point of the week, in three numbers

| | |
|---|---|
| defconfig | 17 lines  <- the only thing worth committing |
| .config | 5,301 lines |
| output/ | 12 GB |

Seventeen lines fully describe the system: aarch64, kernel 6.18.7, ext4 rootfs,
DHCP on eth0, root password. Anyone with that file rebuilds the identical system
six months from now on a different machine. savedefconfig records only what
differs from the defaults, which is why it stays this short.

Weeks 1-5 worked, but the process lived in my terminal history — not shareable,
not repeatable, not maintainable. Commit the recipe, not the meal.

## What a real init actually does

Week 5's init was three lines: mount /proc, /sys, exec a shell. Buildroot's
/sbin/init starts services in sequence and runs a login prompt:

    S01seedrng  S01syslogd  S02klogd  S02sysctl  S11modules  S40network  S50crond

The numeric prefixes are the boot order — init runs them in ascending order.
S = start, K = kill on shutdown. Classic SysV init: want a service earlier, give
it a lower number.

That gap is the difference between a teaching rootfs and a usable system. 261
commands in /bin, /sbin and /usr/bin, all from one BusyBox binary.

Also different from week 5: the rootfs now lives on a virtual disk
(root=/dev/vda) instead of in RAM, so it mounts read-only first, then re-mounts
read-write.

## Problems hit

**Root login rejected the password.** Changing a system-level setting (root
password) invalidates no package stamp, so Buildroot skipped rebuilding the
rootfs. Buildroot tracks state with stamp files and its dependency tracking is
deliberately loose — the tradeoff for its simplicity, and the reason Yocto's
sstate-cache exists. (The actual cause turned out to be simpler: the saved
password was "1", not what I thought I had typed.)

**Deleting output/target broke the build** (/etc/inittab not found). BusyBox's
stamp still said "installed", so it never reinstalled its files. Deleting the
target tree by hand desynchronises stamps from reality. Fix:

    find output/build -name ".stamp_target_installed" -delete

**init=/bin/sh** bypasses /sbin/init entirely and runs a shell as PID 1 — no
services, no login. A genuinely useful recovery trick when init is broken or the
password is lost. Side effect worth noticing: df failed with "/proc/mounts: No
such file or directory", because skipping init means nobody mounted /proc. Proof
that init does more than launch a shell — it sets up the userspace environment.

**savedefconfig writes to BR2_DEFCONFIG**, which points back at the original
defconfig file, not to ./defconfig as expected. To control the destination:

    make savedefconfig BR2_DEFCONFIG=$(pwd)/../my_defconfig

## Build environment notes

Needed unzip and rsync on the host. The VM had no swap, so a -j4 build exhausted
8 GB of RAM and froze the machine hard enough that SSH stopped responding. Fixes:

    sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
    sudo mkswap /swapfile && sudo swapon /swapfile

Then build under tmux with -j2. Buildroot writes progress to disk continuously,
so an interrupted build resumes rather than restarting.

Buildroot also downloads and builds host QEMU 11.0 from source unless disabled —
a large chunk of the build time for something already installed.

## Buildroot vs Yocto

Buildroot is simpler and rebuilds broadly; Yocto tracks dependencies precisely
and rebuilds incrementally. Yocto is what BSP job descriptions ask for, but
learning it first is overwhelming. Buildroot teaches the idea of a build system
at low complexity.

## Commands

    make list-defconfigs | grep qemu
    make qemu_aarch64_virt_defconfig
    make menuconfig
    make -j2
    make savedefconfig

    qemu-system-aarch64 -M virt -cpu cortex-a57 -m 512M -nographic \
      -kernel output/images/Image \
      -drive file=output/images/rootfs.ext4,if=none,format=raw,id=hd0 \
      -device virtio-blk-device,drive=hd0 \
      -append "root=/dev/vda console=ttyAMA0"

Add init=/bin/sh to the append line to bypass init and login entirely.

## Phase 0 complete

power on -> U-Boot (w2) -> network load (w3) -> kernel (w4) -> rootfs (w5) -> shell

Every link built by hand, then automated (w6). Next: Jetson Orin Nano and a real
project.
