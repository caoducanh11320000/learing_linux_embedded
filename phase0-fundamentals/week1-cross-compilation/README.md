# Week 1 — Cross-compilation

**Goal:** understand cross-compilation by building the same `hello.c` for
different target architectures on an aarch64 host (Ubuntu VM on Apple M2).

## What I did
Compiled `hello.c` three ways:

| Binary        | Arch        | Linking  | Notes                                    |
|---------------|-------------|----------|------------------------------------------|
| hello_native  | aarch64     | dynamic  | Native build (host is already aarch64)   |
| hello_arm64   | aarch64     | static   | Project target — matches QEMU virt/Jetson|
| hello_armhf   | 32-bit ARM  | static   | A real cross-compile; runs via qemu-arm  |

## Key takeaways
1. **Same source, different target arch = cross-compilation.** `hello_armhf`
   is 32-bit ARM while the host is 64-bit aarch64.
2. **Static vs dynamic linking:** static bundles the libraries in (common on
   embedded targets that lack system libs); dynamic borrows them at runtime.
3. **Why only hello_armhf needs qemu-arm:** the host is aarch64, so the two
   aarch64 binaries run natively; only the 32-bit "foreign" binary needs the
   qemu-arm user-mode emulator.

## Commands
See build steps in this directory. Toolchains used:
`gcc`, `arm-linux-gnueabihf-gcc`, `aarch64-linux-gnu-gcc`; runner: `qemu-arm`.
