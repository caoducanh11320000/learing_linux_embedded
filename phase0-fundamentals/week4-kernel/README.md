# Week 4 — Building and Booting My Own Kernel

**Goal:** build a Linux kernel from source, load it over TFTP, and hand control
to it manually with booti — doing by hand what autoboot normally does.

## What I did
- Cloned mainline Linux, configured with arm64 defconfig, built Image
- Copied Image to the TFTP directory on the host
- In U-Boot: dhcp, tftp the kernel into RAM, set bootargs, booti
- Reached a kernel panic on missing rootfs — the expected outcome

## Key takeaways

**Why Device Tree exists.** Before DT, board descriptions were hard-coded in the
kernel: thousands of board files bloating the tree, and changing board meant
rebuilding the kernel. DT splits hardware description (data) from kernel code, so
one kernel image runs on many boards — just swap the DTB.

**Three things are needed to boot.** Kernel image, device tree, and bootargs.
Missing any one and the system will not come up. This is why booti takes multiple
arguments: booti <kernel> <initrd|-> <dtb>.

**bootargs travels inside the Device Tree.** U-Boot does not pass it separately.
It writes the string into the DTB at /chosen/bootargs, then passes the DTB
address to the kernel in a CPU register. The DTB is the only vehicle across the
handover boundary — so a corrupted DTB loses both the hardware description and
the boot parameters.

**A panic on missing rootfs is success.** It proves everything before it worked:
the image was valid, the handover succeeded, the DTB was read, the console came
up, and memory/drivers initialised. Seeing the panic message at all is the
strongest evidence — if the console had failed, the screen would be silent.

## Reading the boot log

    Hardware name: linux,dummy-virt (DT)

The (DT) confirms the kernel parsed the device tree and identified the board.

    unknown-block(0,0)

Major/minor 0,0 means no root device was specified — correct, since bootargs only
had console=ttyAMA0 and no root=.

The call trace reads bottom-up: kernel_init -> prepare_namespace -> mount_root ->
mount_root_generic (fails) -> vpanic. This is exactly the last step before
userspace would have started.

## Numbers worth remembering

| Item | Size |
|------|------|
| u-boot.bin (Week 2) | ~1 MB |
| Image (this week) | 49 MB |

The 49x difference is concrete evidence for the multi-stage boot chain: a 49 MB
kernel obviously cannot run from a few tens of KB of internal SRAM, so DRAM must
be initialised first by a small earlier stage.

Kernel reached panic in under 1 second (timestamps ~0.86s) — a baseline for
later boot-time optimisation work.

Build time: 8 hours wall clock but only ~32 min of CPU time (user+sys). The gap
was the VM being suspended, not slow compilation. Lesson: keep the host awake
(caffeinate) or run long builds under tmux.

## Commands

    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    make defconfig
    make -j$(nproc) Image
    sudo cp arch/arm64/boot/Image /srv/tftp/ && sudo chmod 644 /srv/tftp/Image

    qemu-system-aarch64 -M virt -cpu cortex-a57 -m 2G -nographic \
      -bios u-boot.bin \
      -netdev user,id=net0,tftp=/srv/tftp \
      -device virtio-net-device,netdev=net0

    # in U-Boot
    dhcp
    setenv serverip 10.0.2.2
    tftp 0x40400000 Image
    setenv bootargs 'console=ttyAMA0'
    booti 0x40400000 - 0x40000000

## Next
Week 5 adds the missing piece: a root filesystem, so the kernel has something to
execute and can reach a shell.
