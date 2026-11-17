#!/bin/bash

set -euo pipefail

BUILDKIT_VERSION="0.33.0"
CNI_PLUGINS_VERSION="1.9.1"
CONTAINERD_VERSION="2.3.5"
K8S_VERSION="1.37.2"
LIBPATHRS_VERSION="0.2.5"
LIBSECCOMP_VERSION="2.6.0"
NERDCTL_VERSION="2.3.5"
RUNC_VERSION="1.5.1"

GIT_PULL=0
CLEAN=0

MARCH="arm64"

help_message () {
	# Display Help
	echo "Create symbolic links for Raspberry PI5 K8S configuration"
	echo
	echo "Syntax: ${0} [-h|-p|-a <arch>|-c]"
	echo "options:"
	echo "-h          Print help."
	echo "-p          Run git pull before running other links."
	echo "-a <arch>   Machine arch: arm64, amd64. Default: arm64 "
	echo "-c          Remove bin files and existing symlinks before creating them."
	echo
}

link_table () {
	cat <<EOF
config/modules-load.d-k8s.conf /etc/modules-load.d/k8s.conf
config/sysctl.d-k8s.conf /etc/sysctl.d/k8s.conf
config/systemd-system-containerd.service /etc/systemd/system/containerd.service
config/buildkit-buildkitd.toml /etc/buildkit/buildkitd.toml
config/conteinerd-config.toml /etc/containerd/config.toml
config/systemd-system-buildkit.service /etc/systemd/system/buildkit.service
config/systemd-system-buildkit.socket /etc/systemd/system/buildkit.socket
config/systemd-system-kubelet.service /etc/systemd/system/kubelet.service
config/default-kubelet /etc/default/kubelet
config/kubelet.service.d-10-kubeadm-flags.env /etc/systemd/system/kubelet.service.d/10-kubeadm-flags.env
bin/cni-plugins/$CNI_PLUGINS_VERSION /opt/cni/bin
bin/buildkit/$BUILDKIT_VERSION/buildctl /usr/bin/buildctl
bin/buildkit/$BUILDKIT_VERSION/buildkit-cni-bridge /usr/bin/buildkit-cni-bridge
bin/buildkit/$BUILDKIT_VERSION/buildkit-cni-firewall /usr/bin/buildkit-cni-firewall
bin/buildkit/$BUILDKIT_VERSION/buildkit-cni-host-local /usr/bin/buildkit-cni-host-local
bin/buildkit/$BUILDKIT_VERSION/buildkit-cni-loopback /usr/bin/buildkit-cni-loopback
bin/buildkit/$BUILDKIT_VERSION/buildkitd /usr/bin/buildkitd
bin/buildkit/$BUILDKIT_VERSION/buildkit-qemu-arm /usr/bin/buildkit-qemu-arm
bin/buildkit/$BUILDKIT_VERSION/buildkit-qemu-i386 /usr/bin/buildkit-qemu-i386
bin/buildkit/$BUILDKIT_VERSION/buildkit-qemu-ppc64le /usr/bin/buildkit-qemu-ppc64le
bin/buildkit/$BUILDKIT_VERSION/buildkit-qemu-riscv64 /usr/bin/buildkit-qemu-riscv64
bin/buildkit/$BUILDKIT_VERSION/buildkit-qemu-s390x /usr/bin/buildkit-qemu-s390x
bin/buildkit/$BUILDKIT_VERSION/buildkit-qemu-x86_64 /usr/bin/buildkit-qemu-x86_64
bin/buildkit/$BUILDKIT_VERSION/buildkit-runc /usr/bin/buildkit-runc
bin/containerd/$CONTAINERD_VERSION/containerd /usr/bin/containerd
bin/containerd/$CONTAINERD_VERSION/containerd-shim-runc-v2 /usr/bin/containerd-shim-runc-v2
bin/containerd/$CONTAINERD_VERSION/containerd-stress /usr/bin/containerd-stress
bin/containerd/$CONTAINERD_VERSION/ctr /usr/bin/ctr
bin/nerdctl/$NERDCTL_VERSION/nerdctl /usr/bin/nerdctl
bin/runc/$RUNC_VERSION/runc.$MARCH /usr/bin/runc
bin/kubernetes/$K8S_VERSION/kubelet /usr/bin/kubelet
bin/kubernetes/$K8S_VERSION/kubeadm /usr/bin/kubeadm
bin/kubernetes/$K8S_VERSION/kubectl /usr/bin/kubectl
EOF
}

clean_links () {
	while read -r src dst; do
		if [ -z "$src" ]; then
			continue
		fi
		if [ ! -L "$dst" ]; then
			if [ -e "$dst" ]; then
				echo "  => Skipping (not a symlink): $dst"
			fi
			continue
		fi
		if [ -e "$dst" ] && [ "$(readlink "$dst")" != "$BASEDIR/$src" ]; then
			echo "  => Skipping (foreign symlink -> $(readlink "$dst")): $dst"
			continue
		fi
		echo "  => Removing: $dst"
		rm -f "$dst"
	done < <(link_table)
}

while getopts ":hpa:c" option; do
	case "$option" in
		p) # Run git pull
			GIT_PULL=1
		;;
		a) # Machine arch
			MARCH="$OPTARG"
		;;
		c) # Clean bin files and existing symlinks
			CLEAN=1
		;;
		h) # display Help
			help_message
			exit
		;;
		\?) # Invalid option
			echo "Invalid option: -$option"
			echo
			help_message
			exit 1
		;;
	esac
done

case "$MARCH" in
	'arm64'|'amd64')
		echo "Using $MARCH binaries"
	;;
	*)
		echo "Invalid arch: $MARCH"
		echo "Please select one of: arm64, amd64"
		exit 1
	;;
esac

if [ "$EUID" -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi

INIT_PATH=$(pwd)
SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

BUILDKIT_FILE="buildkit-v$BUILDKIT_VERSION.linux-$MARCH.tar.gz"
CNI_PLUGINS_FILE="cni-plugins-linux-$MARCH-v$CNI_PLUGINS_VERSION.tgz"
CONTAINERD_FILE="containerd-$CONTAINERD_VERSION-linux-$MARCH.tar.gz"
K8S_FILE="kubernetes-node-linux-$MARCH.tar.gz"
LIBPATHRS_FILE="libpathrs-$LIBPATHRS_VERSION.tar.xz"
LIBSECCOMP_FILE="libseccomp-$LIBSECCOMP_VERSION.tar.gz"
NERDCTL_FILE="nerdctl-$NERDCTL_VERSION-linux-$MARCH.tar.gz"

cd "$BASEDIR"
if [ "$GIT_PULL" -eq "1" ]; then
	echo "=> Updating repo..."
	git pull
fi

echo "=> Checking dependencies: rust..."
if command -v rustc >/dev/null 2>&1; then
	echo "Rust is installed: $(rustc --version)"
else
	echo "Rust is not installed"
	exit 1
fi

echo "=> Installing dependencies..."
apt install -y clang lld gperf

if [ "$CLEAN" -eq "1" ]; then
	clean_links
	echo "=> Removing bin folder..."
	rm -rf "$BASEDIR/bin"
fi

echo "=> Preparing bin folder..."
mkdir -p bin
cd bin

echo "=> Downloading binaries..."
if [ -f "$BUILDKIT_FILE" ]; then
	echo "  => Skipping download (exists): $BUILDKIT_FILE"
else
	curl -fSLO "https://github.com/moby/buildkit/releases/download/v$BUILDKIT_VERSION/$BUILDKIT_FILE"
fi

if [ -f "$CNI_PLUGINS_FILE" ]; then
	echo "  => Skipping download (exists): $CNI_PLUGINS_FILE"
else
	curl -fSLO "https://github.com/containernetworking/plugins/releases/download/v$CNI_PLUGINS_VERSION/$CNI_PLUGINS_FILE"
fi

if [ -f "$CONTAINERD_FILE" ]; then
	echo "  => Skipping download (exists): $CONTAINERD_FILE"
else
	curl -fSLO "https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/$CONTAINERD_FILE"
fi

if [ -f "$K8S_FILE" ]; then
	echo "  => Skipping download (exists): $K8S_FILE"
else
	curl -fSLO "https://dl.k8s.io/v$K8S_VERSION/$K8S_FILE"
fi

if [ -f "$LIBPATHRS_FILE" ]; then
	echo "  => Skipping download (exists): $LIBPATHRS_FILE"
else
	curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/$LIBPATHRS_FILE"
fi

if [ -f "$LIBSECCOMP_FILE" ]; then
	echo "  => Skipping download (exists): $LIBSECCOMP_FILE"
else
	curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/$LIBSECCOMP_FILE"
fi

if [ -f "$NERDCTL_FILE" ]; then
	echo "  => Skipping download (exists): $NERDCTL_FILE"
else
	curl -fSLO "https://github.com/containerd/nerdctl/releases/download/v$NERDCTL_VERSION/$NERDCTL_FILE"
fi

if [ -f "runc.$MARCH" ]; then
	echo "  => Skipping download (exists): runc.$MARCH"
else
	curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$MARCH"
fi

echo "=> Moving binaries..."
mkdir -p libpathrs
mv "$LIBPATHRS_FILE" libpathrs/
cd libpathrs
if [ -d "$LIBPATHRS_VERSION" ]; then
	echo "  => Skipping extract (exists): $LIBPATHRS_VERSION"
else
	tar xf "$LIBPATHRS_FILE"
	mv "libpathrs-$LIBPATHRS_VERSION" "$LIBPATHRS_VERSION"
	rm "$LIBPATHRS_FILE"
fi
cd ..

mkdir -p libseccomp
mv "$LIBSECCOMP_FILE" libseccomp/
cd libseccomp
if [ -d "$LIBSECCOMP_VERSION" ]; then
	echo "  => Skipping extract (exists): $LIBSECCOMP_VERSION"
else
	tar xf "$LIBSECCOMP_FILE"
	mv "libseccomp-$LIBSECCOMP_VERSION" "$LIBSECCOMP_VERSION"
	rm "$LIBSECCOMP_FILE"
fi
cd ..

mkdir -p "runc/$RUNC_VERSION"
if [ -f "runc/$RUNC_VERSION/runc.$MARCH" ]; then
	echo "  => Skipping extract (exists): runc/$RUNC_VERSION"
else
	chmod +x "runc.$MARCH"
	mv "runc.$MARCH" "runc/$RUNC_VERSION"
fi

mkdir -p containerd
mv "$CONTAINERD_FILE" containerd/
cd containerd
if [ -d "$CONTAINERD_VERSION" ]; then
	echo "  => Skipping extract (exists): $CONTAINERD_VERSION"
else
	tar xf "$CONTAINERD_FILE"
	mv "bin" "$CONTAINERD_VERSION"
	rm "$CONTAINERD_FILE"
fi
cd ..

mkdir -p kubernetes
mv "$K8S_FILE" kubernetes/
cd kubernetes
if [ -d "$K8S_VERSION" ]; then
	echo "  => Skipping extract (exists): $K8S_VERSION"
else
	tar xf "$K8S_FILE"
	mv "kubernetes/node/bin" "$K8S_VERSION"
	rm "$K8S_FILE"
fi
cd ..

mkdir -p "cni-plugins/$CNI_PLUGINS_VERSION"
mv "$CNI_PLUGINS_FILE" cni-plugins/
cd cni-plugins
if [ -f "$CNI_PLUGINS_VERSION/bridge" ]; then
	echo "  => Skipping extract (exists): cni-plugins/$CNI_PLUGINS_VERSION"
else
	tar xf "$CNI_PLUGINS_FILE" -C "$CNI_PLUGINS_VERSION"
	rm "$CNI_PLUGINS_FILE"
fi
cd ..

mkdir -p "nerdctl/$NERDCTL_VERSION"
mv "$NERDCTL_FILE" nerdctl/
cd nerdctl
if [ -f "$NERDCTL_VERSION/nerdctl" ]; then
	echo "  => Skipping extract (exists): nerdctl/$NERDCTL_VERSION"
else
	tar xf "$NERDCTL_FILE" -C "$NERDCTL_VERSION"
	rm "$NERDCTL_FILE"
fi
cd ..

mkdir -p buildkit
mv "$BUILDKIT_FILE" buildkit/
cd buildkit
if [ -d "$BUILDKIT_VERSION" ]; then
	echo "  => Skipping extract (exists): $BUILDKIT_VERSION"
else
	tar xf "$BUILDKIT_FILE"
	mv "bin" "$BUILDKIT_VERSION"
	rm "$BUILDKIT_FILE"
fi
cd ..

echo "=> Install libpathrs..."
cd "libpathrs/$LIBPATHRS_VERSION"
make release EXTRA_RUSTC_FLAGS="-C linker=clang"
make install
cd ../..

echo "=> Install libseccomp..."
cd "libseccomp/$LIBSECCOMP_VERSION"
./configure
make
make install
cd ../..

echo "=> Create symlinks..."

while read -r src dst; do
	if [ -z "$src" ]; then
		continue
	fi
	if [ -L "$dst" ]; then
		if [ -e "$dst" ]; then
			echo "  => Skipping (already exists): $dst"
		else
			echo "  => Skipping (broken symlink -> $(readlink "$dst")): $dst"
		fi
		continue
	fi
	if [ -e "$dst" ]; then
		echo "  => Skipping (already exists): $dst"
		continue
	fi
	mkdir -p "$(dirname "$dst")"
	echo "  => Creating link: $src -> $dst"
	ln -s "$BASEDIR/$src" "$dst"
done < <(link_table)

echo "=> Apply kernel settings..."
sysctl --system >/dev/null
modprobe overlay
systemctl daemon-reload

echo "=> Enable and start containerd..."
systemctl enable --now containerd

echo "=> Check cgroup memory controller..."
echo "=> Enable and start buildkit..."
systemctl enable --now buildkit.socket
systemctl enable --now buildkit.service

cmdline="/boot/firmware/cmdline.txt"
if [ ! -f "$cmdline" ]; then
	cmdline="/boot/cmdline.txt"
fi
required="cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1"
if [ ! -f "$cmdline" ]; then
	echo "  => Warning: cmdline file not found, cannot check cgroup_disable=memory"
else
	filtered=""
	for token in $(cat "$cmdline"); do
		if [ "$token" = "cgroup_disable=memory" ]; then
			echo "  => Removing cgroup_disable=memory"
			continue
		fi
		filtered="$filtered $token"
	done
	for token in $required; do
		case " $filtered " in
			*" $token "*) continue ;;
		esac
		filtered="$filtered $token"
		echo "  => Adding $token"
	done
	if [ "${filtered# }" != "$(cat "$cmdline")" ]; then
		cp "$cmdline" "$cmdline.bak"
		printf '%s\n' "${filtered# }" > "$cmdline"
		echo "  => cmdline updated (backup: $cmdline.bak)"
	else
		echo "  => cmdline OK: no cgroup_disable=memory, required options present"
	fi
fi
if grep -qw memory /sys/fs/cgroup/cgroup.controllers; then
	echo "  => memory controller available"
else
	echo "  => Warning: memory controller not available in this boot."
	echo "     kubelet cannot create QoS cgroups without it."
	echo "     Reboot so the firmware reads the updated cmdline.txt."
fi

echo "=> Enable kubelet..."
systemctl enable --now kubelet

echo "=> Validation..."
echo "  buildkit.socket: $(systemctl is-active buildkit.socket)"
echo "  buildkit.service: $(systemctl is-active buildkit.service)"
echo "  containerd.service:  $(systemctl is-active containerd)"
echo "  kubelet.service: $(systemctl is-active kubelet)"
echo "  ip_forward: $(sysctl -n net.ipv4.ip_forward)"
echo "  cgroup memory controller: $(grep -qw memory /sys/fs/cgroup/cgroup.controllers && echo present || echo absent)"

cd "$INIT_PATH"
