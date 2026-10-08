#!/bin/sh
# build-all.sh — build the pve-triton .debs on a Debian (12/13) build host.
# Usage: build-all.sh <checkout-root>
# Expects:
#   <root>/dxvk            osy/dxvk with submodules initialized
#   <root>/virglrenderer   utmapp/virglrenderer @ dev/neptune-linux
#   <root>/packaging       this repo's packaging/ tree
# NOTE: the QEMU package (pve-qemu-kvm 11.1.1-2+triton1) is NOT built here —
# it is built inside the proxmox/pve-qemu checkout, after this script has
# installed pve-triton-virglrenderer (docs/porting.md Step 3).
set -e

ROOT="${1:?usage: build-all.sh <checkout-root>}"
PKGS="dxvk virglrenderer stack"

for pkg in $PKGS; do
	echo "=== building pve-triton-${pkg} ==="
	if [ "$pkg" = "stack" ]; then
		# Meta package: source tree is packaging/pve-triton-stack itself
		# (contains debian/ + etc/ overlay layout).
		rm -rf "$ROOT/stack"
		mkdir -p "$ROOT/stack"
		cp -a "$ROOT/packaging/pve-triton-stack/." "$ROOT/stack/"
		chmod 755 "$ROOT/stack/debian/rules"
		cd "$ROOT/stack"
	else
		rm -rf "$ROOT/$pkg/debian"
		cp -a "$ROOT/packaging/pve-triton-$pkg/debian" "$ROOT/$pkg/debian"
		chmod 755 "$ROOT/$pkg/debian/rules"
		cd "$ROOT/$pkg"
	fi
	dpkg-buildpackage -us -uc -b
	# Install so later packages' Build-Depends on this one are satisfied.
	# (arch is _amd64 for component packages, _all for the stack meta package)
	dpkg -i "$ROOT"/pve-triton-${pkg}_*.deb 2>/dev/null || \
		apt-get install -y -f -qq
	cd "$ROOT"
done

echo "=== built packages ==="
ls -1 "$ROOT"/*.deb
