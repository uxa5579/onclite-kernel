# Patch notes

This folder intentionally does not contain a universal `.patch` for ReSukiSU manual hooks because kernel 4.9 non-GKI trees vary heavily. ReSukiSU's own documentation says non-GKI has no universal boot image/build method and requires a bootable open-source kernel first.

The build scripts use the official ReSukiSU setup script and enable manual-hook config flags. If your kernel source does not already contain manual hooks and the ReSukiSU build fails with missing hook checks, follow the manual hook reference from ReSukiSU and patch these files in your selected source:

- `fs/stat.c`
- `fs/exec.c`
- `fs/open.c`
- `kernel/reboot.c` or `kernel/sys.c`
- `drivers/input/input.c` when needed
- `fs/read_write.c` when needed

For SUSFS, `scripts/05_try_susfs.sh` attempts to apply the `1.4.2-kernel-4.9` branch patches. Patch rejects are expected on many 4.9 trees.
