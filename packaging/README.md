# Triton/Neptune host stack for Proxmox VE — packaging

Per project convention, every host-side component ships as a Debian package. **Since the 2026-10-08 pivot to the `pve-qemu` base** (see `docs/porting.md` Step 3), the package set is:

| package | built from | notes |
|---|---|---|
| `pve-triton-dxvk` | `osy/dxvk` (headless dmabuf WSI) | private libdir + `ld.so.conf.d` drop-in + plain-name symlinks so the render server's fallback `dlopen("libd3d11.so")` works with no env |
| `pve-triton-virglrenderer` | `utmapp/virglrenderer` `dev/neptune-linux` | **system install (`/usr`)**, `Conflicts/Replaces: libvirglrenderer1, libvirglrenderer-dev, virglrenderer` — `/usr/bin/kvm` links the Neptune-capable library directly, no `LD_LIBRARY_PATH` |
| `pve-qemu-kvm` `11.1.1-2+triton1` | **`proxmox/pve-qemu`** with the Triton quilt series in `debian/patches/triton/` | built inside the pve-qemu checkout (`make -j4`), NOT from this tree — the old `pve-triton-qemu` (utmapp fork, private prefix, wrapper, dispatcher shim) is retired |
| `pve-triton-stack` | this tree (`pve-triton-stack/`) | meta; depends on all three; ships only the `/etc/pve-triton/env` conffile (documentation of optional `NPT_*` overrides) |

Build the first two and the meta with `build-all.sh`; build the QEMU package in the `pve-qemu` checkout per `docs/porting.md` Step 3 (must happen **after** `pve-triton-virglrenderer` is installed so configure finds virglrenderer 1.3.0 via the default pkg-config path).
