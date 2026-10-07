# Next steps and open questions

Questions that must be answered before committing to build work (Phase 1 in [feasibility.md](feasibility.md#7-phased-validation-plan)). Each has a concrete way to resolve it. Ordered roughly by how much they gate everything else.

## Open questions

### Q1. Which virglrenderer branch carries the Linux Neptune + DXVK path? — RESOLVED

**`utmapp/virglrenderer` branch `dev/neptune-linux`** (verified by direct inspection of the branch, 2026-10-07). Meson options `-Dneptune=true` and `-Dvenus=true`; build target `server/virgl_render_server`. On Linux the render server `dlopen`s the host D3D backend libraries **`libd3d11.so` and `libdxgi.so`** (from the DXVK fork) and **`libvkd3d-proton-d3d12.so`** (optional, D3D12 only), overridable at runtime via the `NPT_D3D11_LIBRARY_PATH` / `NPT_DXGI_LIBRARY_PATH` / `NPT_D3D12_LIBRARY_PATH` env vars (`src/neptune/npt_library_names.h`). `macos-next` remains macOS-only (D3DMetal/DXMT) and is irrelevant to the port.

### Q2. Which QEMU base does `utmapp/qemu` (`utm-edition` branch) track, and does it accept PVE's argument set? — RESOLVED (base version)

**`utmapp/qemu` branch `dev/neptune-linux`** is the Linux-targeted fork; base version is **QEMU 10.0.12** (`VERSION` file). Its machine types run through `pc-q35-10.0`, covering PVE 8.x guests (`pc-q35-9.2`) and PVE 9.x guests (`pc-q35-10.x`). The `utm-edition`/`utm-edition-v*` branches are macOS-oriented — use `dev/neptune-linux`. The remaining check is a dry-run of PVE's full generated argument set (Step 3 of [porting.md](porting.md#step-3--package-the-qemu-fork)), which needs the PVE host.

### Q3. Does the `neptune=true` device property exist outside UTM's QEMU fork? — RESOLVED

**It is a fork-only device property, but a clean one**: `hw/display/virtio-gpu-gl.c` in the `dev/neptune-linux` branch defines `DEFINE_PROP_BIT("neptune", ...)`, requires `blob` and `hostmem` to be enabled, and errors out at device realize if the linked virglrenderer lacks Neptune support ("virglrenderer does not support neptune"). No upstreaming evidence exists, so the QEMU fork — or backporting this property onto PVE's QEMU as a much smaller patch surface — remains required.

### Q4. How do frames reach the Proxmox console?

NoVNC attaches to QEMU's VNC server; it is unknown whether virtio-gpu **blob-resource scanout** renders there on a headless host (no EGL/GL display on the server). Candidates in order of preference: SPICE (handles dmabuf-backed surfaces), `egl-headless` display + VNC, patched VNC backend.

**Resolve by:** Phase 2 smoke test (Linux guest) — this answers the question for Windows too, since scanout is guest-agnostic. Before any build: scan QEMU/SPICE issue trackers and the UTM Graphics documentation for blob-scanout-over-VNC/SPICE status.

### Q5. Exact driver release to use for Windows x64 — RESOLVED

Latest release is **`v0.3`** of `osy/kvm-guest-drivers-windows` with asset **`viogpu3d-x64-signed.zip`** for Windows x64 (an `arm64x` variant also exists). Verify the INF's supported architectures after unzipping, before installing into the guest.

### Q6. Host iGPU generation and Vulkan dmabuf capability

DXVK needs Vulkan 1.3 (ANV: Gen9/Skylake+, Mesa 22.3+); the Neptune dmabuf WSI additionally needs VK_EXT_external_memory_dma_buf **import and export**, and the Triton architecture needs cross-render-server-context texture sharing. Gen9 is the theoretical floor; Gen11+ (Ice Lake) or Xe is safer.

**Resolve by:** on the PVE host: `lspci -nn | grep -i vga`, `vulkaninfo --summary`, and a minimal Vulkan dmabuf import/export smoke test (Phase 0).

### Q7. Where does the forked DXVK live and is its Linux native build reproducible? — RESOLVED (with a build-recipe update)

The fork is **`osy/dxvk`** (branch `master`). **Build-recipe correction vs the Neptune post**: the old `-Dnative_dmabuf=true` no longer exists; the current option is **`-Dnative_headless=true`** ("headless (no-window) WSI carrier for DXVK Native"), with `native_sdl2`/`native_sdl3`/`native_glfw` disabled. It produces `libd3d11.so` and `libdxgi.so` with the shared-texture dmabuf export path built in (Vulkan external-memory export in `src/d3d11/d3d11_texture.cpp` and friends). D3D12 additionally needs `libvkd3d-proton-d3d12.so` from a vkd3d-proton build — optional, since the target is D3D11 first. Note `osy/build-mesa` is guest-side MSYS2 tooling only, not host build scripts. Remaining check: the build completes in the Debian 13 container (Step 1 of [porting.md](porting.md)).

### Q8. Licensing review for distribution

Personal/lab use is fine. If this repo ever publishes binaries (.deb packages of the QEMU fork, etc.), a license review is needed: QEMU (GPLv2), virglrenderer (MIT), Mesa (MIT/X11), DXVK (Zlib/LGPL), WDDM driver stack (check `kvm-guest-drivers-windows` licensing, GPL-family). VirtualBox-derived reference code is GPLv3 and must not be mixed in (per the Triton post's own analysis).

**Resolve by:** a one-pass license audit per repo before any binary is published. Defer until packaging is on the table.

## Decision points

1. **Go/no-go after Phase 1.** If the QEMU fork cannot run PVE's argument set (Q2) or virglrenderer's Linux Neptune path is macOS-only now (Q1), the honest outcome is: document the blocker, track upstream, revisit when osy lands Linux Triton support in a mainline-able form.
2. **Forked-QEMU delivery method — resolved by convention:** Debian packages. `pve-triton-dxvk` / `pve-triton-virglrenderer` / `pve-triton-qemu` built per the packaging strategy in [porting.md](porting.md#1-packaging-strategy), served from a local APT repo, coexisting with `pve-qemu-kvm` (no Conflicts/Replaces) with dispatch via the package-provided `/usr/bin/pve-triton-qemu` wrapper. Do not replace or shadow the packaged QEMU. **DKMS is not applicable** — the stack has no out-of-tree host kernel modules; add a `pve-triton-dkms` package only if a future change requires one.
3. **Scope of the eventual tooling**: the .deb packaging pipeline *is* the tooling — `debian/` directories in each fork checkout plus a container build script and the local APT repo setup. Decide after Phase 2 whether the Windows guest-side materials (driver download + `pnputil` steps) also get wrapped in an Ansible/`qm` script or stay as the documented manual procedure in [porting.md](porting.md#step-6-windows-guest-driver-install).
4. **Which VM to sacrifice**: do all bring-up on a disposable test VM; enable backups/snapshots before driver installs (driver rollbacks under WDDM can leave a VM unbootable — keep the `vga: std` config recipe handy for rescue).
