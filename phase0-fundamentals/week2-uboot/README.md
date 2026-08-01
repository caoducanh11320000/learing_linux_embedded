# Week 2 — U-Boot & the Boot Chain

**Goal:** understand why a bootloader exists, why the boot chain is split into
stages, and get hands-on with the U-Boot shell (QEMU aarch64 virt board).

## What I did
- Built U-Boot from source for qemu_arm64_defconfig (cross-compiled with aarch64-linux-gnu-)
- Booted it under qemu-system-aarch64 and interrupted autoboot to reach the shell
- Explored: bdinfo, printenv, setenv, md, mw, help booti, bootflow scan

## Key takeaways

**Why a bootloader is necessary.** At reset, DRAM is uninitialised, storage
controllers are down, and the kernel is still sitting on disk. Something must
initialise the hardware and load the kernel into RAM first.

**Why the chain is split into stages.** Right after reset the only usable memory
is a small internal SRAM (tens of KB). A full bootloader (~1 MB) does not fit
there. So a tiny first stage (SPL) initialises DRAM, and only then can the larger
U-Boot run from DRAM. Each stage initialises enough hardware for the next, larger
stage to run. DRAM init cannot live in Boot ROM because Boot ROM is hard-wired,
while DRAM differs from board to board — that code must stay modifiable.

**Environment variables = runtime configuration.** Changing bootdelay, bootargs
or boot_targets alters boot behaviour with no rebuild and no re-flash. bootcmd is
not a special mechanism — it is just a shell command string that U-Boot runs
automatically. Anything autoboot does, I can type by hand, and I can also write
my own script into bootcmd.

**How bootargs reaches the kernel.** U-Boot does not leave it somewhere for the
kernel to find. It copies the string into the Device Tree (/chosen/bootargs),
places the DTB in RAM, and passes that address to the kernel at handover. The
kernel knows nothing about U-Boot's environment.

**No memory protection at this level.** mw writes anywhere. I overwrote address
0x40000000 and discovered the original value was 0xd00dfeed (byte-swapped) — the
Device Tree magic number, confirming a DTB was loaded there (matching
fdt_addr=0x40000000). So I had just corrupted the device tree. On real hardware a
wrong mw can hang the system or brick the board.

## Notable addresses on this board

| Item | Address |
|------|---------|
| DRAM start | 0x40000000 (512 MiB) |
| kernel_addr_r | 0x40400000 |
| fdt_addr | 0x40000000 |
| ramdisk_addr_r | 0x44000000 |

Next week these become the arguments to: booti <kernel> - <dtb>

## Build & run

    export CROSS_COMPILE=aarch64-linux-gnu-
    make qemu_arm64_defconfig
    make -j$(nproc)
    qemu-system-aarch64 -M virt -cpu cortex-a57 -m 512M -nographic -bios u-boot.bin

Exit QEMU: Ctrl-A then X.

Note: build required libgnutls28-dev on the host (needed by the HOSTCC tools,
not by the ARM target build).
