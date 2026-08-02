# Week 3 — Network Boot with TFTP

**Goal:** load files from the host into target RAM over the network — the
workflow engineers use daily to test new kernels without touching the device's
storage.

## Why network boot matters
Writing to an SD card takes 3–5 minutes per iteration; reflashing eMMC takes
longer and risks bricking. Over the network it's ~5 seconds. When developing a
kernel or driver you iterate dozens of times a day, so this is the difference
between workable and unworkable.

## What I did
- Set up tftpd-hpa on the host and verified it locally before touching the target
- Ran QEMU with an internal TFTP server (-netdev user,tftp=/srv/tftp)
- In U-Boot: dhcp, set ipaddr/serverip, ping, tftp, md
- Created a command variable and ran it with run

## Key takeaways

**Why TFTP and not HTTP/FTP/SCP.** The TFTP client lives inside U-Boot, which is
size-constrained. TFTP is trivial to implement: UDP, no auth, no encryption, a
few KB of code. Chosen for its constraints, not its features.

**TFTP is reliable despite running on UDP.** It implements its own lockstep
scheme: send one 512-byte block, wait for ACK, then send the next; retransmit on
timeout. Reliability is built into the protocol rather than borrowed from TCP —
at the cost of speed.

**dhcp does more than request an IP.** It also tries to fetch a boot file, and
with no filename configured it invents one from the IP in hex (0A00020F.img),
producing a "File not found" error. The network was fine — only the filename was
missing. Reading the exact error message ("File not found", not "timeout")
identifies which layer actually failed.

**Verifying data really landed in RAM.** After the transfer, md showed the file
contents readable in the ASCII column, including the trailing 0x0a newline.

**bootcmd demystified.** setenv myload '...' plus run myload is exactly the
mechanism bootcmd uses — a variable holding a command string.

## Debugging order (isolate layer by layer)
server running -> file exists -> permissions (644) -> target has IP ->
target can reach server -> filename correct

## Commands
    # host
    sudo apt install tftpd-hpa
    echo "..." | sudo tee /srv/tftp/test.txt
    sudo chmod 644 /srv/tftp/test.txt

    # qemu
    qemu-system-aarch64 -M virt -cpu cortex-a57 -m 512M -nographic \
      -bios u-boot.bin \
      -netdev user,id=net0,tftp=/srv/tftp \
      -device virtio-net-device,netdev=net0

    # u-boot
    dhcp
    setenv serverip 10.0.2.2
    tftp 0x40200000 test.txt
    md 0x40200000 8
