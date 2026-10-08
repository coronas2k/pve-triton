#!/bin/bash
# /usr/bin/kvm dispatcher — pve-triton coexistence shim.
#
# Installed via dpkg-divert (real pve-qemu-kvm binary: /usr/bin/kvm.distrib).
# VMs listed in PVE_TRITON_VMS are routed to the Triton QEMU fork with the
# /etc/pve-triton/env environment; every other VM execs the stock binary.
#
# Fork-routed adjustments (the fork is utmapp/qemu @ dev/neptune-linux,
# base QEMU 10.0.12, no PVE patches):
#   - PVE machine types are version-pinned with a +pveN suffix
#     (e.g. pc-q35-11.0+pve0) which the fork rejects -> downgrade to the
#     fork-compatible base version (pc-q35-10.0).
#   - PVE passes `-id <vmid>`, a pve-qemu-kvm-only option -> strip it.
#   - PVE passes `-iscsi initiator-name=...` (libiscsi option, not in the
#     fork build) -> strip it (inert: no iscsi drives on these VMs).
#   - PVE passes `-cpu host,-cet-ibt,-cet-ss,...` for Windows guests; the
#     fork's QEMU 10 host CPU model has no CET properties -> strip the
#     -cet-* disables (features are simply absent in the fork).
#   - PVE defaults blockdev JSON to "aio":"io_uring"; the fork build has
#     no io_uring support -> rewrite to "threads" (until the fork is
#     rebuilt with liburing-dev).
#   - PVE passes `-vnc ...,password=on` (legacy DES auth); the fork build
#     has no DES cipher backend -> strip the password flag (unix socket is
#     root-only; PVE's web proxy still authenticates). Rebuild the fork
#     with libgcrypt20-dev to restore it.
#   - pve-qemu-kvm defaults to KVM accel when invoked as "kvm"; the fork
#     is vanilla (TCG default) -> append "-accel kvm" if PVE passed none
#     (PVE only passes -accel tcg when the VM's kvm: option is off).
#   - PVE sizes the efidisk0 pflash front-end with an explicit "size" hint
#     (128K) in its blockdev JSON; stock QEMU 11 tolerates the truncation
#     but the fork (10.0.12) honors it strictly -> OVMF finds a var store
#     smaller than its baked-in PcdOvmfFlashNvStorageVariableSize, fails
#     to init it, and runs RAM-only (every NVRAM write — bcfg entries,
#     boot order, Windows' own "Windows Boot Manager" option — is lost at
#     reset). Drop the size hint so the fork maps the whole efidisk LV.
#
# To move a VM to the fork: add its VMID to PVE_TRITON_VMS below (or in
# /etc/pve-triton/env). To revert the shim entirely:
#   dpkg-divert --remove --rename /usr/bin/kvm

PVE_TRITON_VMS="101"
[ -f /etc/pve-triton/env ] && . /etc/pve-triton/env
PVE_TRITON_VMS="${PVE_TRITON_VMS:-}"

id=""; prev=""
for a in "$@"; do
	case "$prev" in
	-id) id="$a" ;;
	esac
	prev="$a"
done

case ",$PVE_TRITON_VMS," in
*,"$id",*)
	export LD_LIBRARY_PATH NPT_D3D11_LIBRARY_PATH NPT_DXGI_LIBRARY_PATH NPT_D3D12_LIBRARY_PATH
	args=()
	skip=0
	for a in "$@"; do
		if [ "$skip" -eq 1 ]; then
			skip=0
			continue
		fi
		if [ "$a" = "-id" ]; then
			skip=1
			continue
		fi
		if [ "$a" = "-iscsi" ]; then
			skip=1
			continue
		fi
		a="$(printf '%s' "$a" | sed -e 's/pc-q35-[0-9.]*+pve[0-9]*/pc-q35-10.0/g' -e 's/,-cet-ibt//g' -e 's/,-cet-ss//g' -e 's/,password=on//g' -e 's/"aio":"io_uring"/"aio":"threads"/g')"
		case "$a" in
		*drive-efidisk0*) a="$(printf '%s' "$a" | sed 's/"size":[0-9]*//')" ;;
		esac
		args+=("$a")
	done
accel=0
for a in "${args[@]}"; do
	[ "$a" = "-accel" ] && accel=1
done
[ "$accel" -eq 0 ] && args+=("-accel" "kvm")
exec /usr/lib/pve-triton/qemu/bin/qemu-system-x86_64 "${args[@]}"
	;;
*)
	exec /usr/bin/kvm.distrib "$@"
	;;
esac
