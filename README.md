# pve-triton

Research into using the **Triton** graphics driver stack (from UTM's author, `osy`) to get hardware-accelerated **DirectX 11** graphics in **Proxmox VE Windows guests**, on an x86 host with an Intel iGPU.

## What is Triton?

Triton is a Windows WDDM driver stack for QEMU's virtio-gpu device, announced in 2026 alongside **Neptune**, a Direct3D protocol-forwarding layer for virglrenderer. Together they bring full DirectX 11 (and Venus-based Vulkan) acceleration to QEMU VMs — something stock QEMU/Proxmox cannot do for Windows guests today, since VirGL has no modern Windows driver.

The stack, end to end:

```
Windows guest                          Proxmox host
─────────────                          ────────────
Application (D3D11)
  → d3d11.dll / DXGI (system)
  → Triton UMD  (neptune_umd.dll)      ← osy/virtio-win-mesa
  → Triton KMD  (viogpu3d.sys)         ← osy/kvm-guest-drivers-windows
  → virtio-gpu device (PCI 1af4:1050)
        │  Neptune protocol (serialized D3D11 API calls)
        ▼
                                     QEMU fork (utmapp/qemu)
                                       virtio-gpu-gl-pci, blob=true, neptune=true
                                     virglrenderer Neptune render server
                                     forked DXVK (D3D11 → Vulkan, dmabuf WSI)
                                     Mesa ANV Vulkan → Intel iGPU
```

## What's in this repo (currently)

| Document | Contents |
| --- | --- |
| [`docs/feasibility.md`](docs/feasibility.md) | Main feasibility study: full stack mapping onto Proxmox, host/guest requirements, integration points, risk register, phased validation plan |
| [`docs/porting.md`](docs/porting.md) | Concrete porting map: per-component build order from UTM's macOS release to a PVE-hosted stack, with commands, pass criteria, and stall points |
| [`docs/next-steps.md`](docs/next-steps.md) | Open questions and decision points that must be resolved before any build work |

No code, scripts, or packages yet — this is a research phase. The eventual goal (if feasibility holds) is build tooling for the forked QEMU/virglrenderer/DXVK on PVE plus a Windows guest driver install guide. The porting map in [`docs/porting.md`](docs/porting.md) sketches what that tooling would automate.

## Sources

- [Introducing Triton: DirectX 11 driver for QEMU](https://blog.getutm.app/2026/introducing-triton-directx-11-driver-for-qemu/) — architecture, guest driver stack, vanilla-QEMU porting notes
- [Introducing Neptune: Direct3D virtualization for QEMU](https://blog.getutm.app/2026/introducing-neptune-direct3d-virtualization-for-qemu/) — Neptune protocol, Linux-host DXVK path, dmabuf WSI
- [Bringup Notes: Building Triton](https://blog.getutm.app/2026/bringup-notes-building-triton/) — build details, hostmem/blob device flags, render server layout
- [osy/kvm-guest-drivers-windows](https://github.com/osy/kvm-guest-drivers-windows) — Windows KMD (`viogpu3d`), see [`viogpu/viogpu3d/BUILDING.md`](https://github.com/osy/kvm-guest-drivers-windows/blob/main/viogpu/viogpu3d/BUILDING.md)
- [osy/virtio-win-mesa](https://github.com/osy/virtio-win-mesa) — guest UMD (Triton D3D11 driver)
- [utmapp/qemu](https://github.com/utmapp/qemu), [utmapp/virglrenderer](https://github.com/utmapp/virglrenderer) — host-side forks
- [Proxmox VE qm docs](https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines) — PVE display options and `virtio-gl` status
