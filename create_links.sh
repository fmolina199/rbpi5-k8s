#!/bin/bash

set -euo pipefail

BUILDKIT_VERSION="0.33.0"
CNI_PLUGINS_VERSION="1.9.1"
CONTAINERD_VERSION="2.3.5"
LIBPATHRS_VERSION="0.2.5"
LIBSECCOMP_VERSION="2.6.0"
NERDCTL_VERSION="2.3.5"
RUNC_VERSION="1.5.1"

GIT_PULL=0

MARCH="arm64"

help_message () {
	# Display Help
	echo "Create symbolic links for Raspberry PI5 K8S configuration"
	echo
	echo "Syntax: ${0} [-h|-p|-a <arch>]"
	echo "options:"
	echo "-h          Print help."
	echo "-p          Run git pull before running other links."
	echo "-a <arch>   Machine arch: arm64, amd64. Default: arm64 "
	echo
}

while getopts ":hpa:" option; do
	case "$option" in
		p) # Run git pull
			GIT_PULL=1
		;;
		a) # Machine arch
			MARCH="$OPTARG"
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
make
make install
cd ../..

echo "=> Create symlinks..."

while read -r src dst; do
	if [ -z "$src" ]; then
		continue
	fi
	if [ -e "$dst" ]; then
		echo "  => Skipping (already exists): $dst"
		continue
	fi
	mkdir -p "$(dirname "$dst")"
	echo "  => Creating link: $src -> $dst"
	ln -s "$BASEDIR/$src" "$dst"
done <<'EOF'
config/modules-load.d-k8s.conf /etc/modules-load.d/k8s.conf
config/sysctl.d-k8s.conf /etc/sysctl.d/k8s.conf
config/systemd-system-containerd.service /etc/systemd/system/containerd.service
config/buildkit-buildkitd.toml /etc/buildkit/buildkitd.toml
config/conteinerd-config.toml /etc/containerd/config.toml
config/systemd-system-buildkit.service /etc/systemd/system/buildkit.service
config/systemd-system-buildkit.socket /etc/systemd/system/buildkit.socket
EOF


cd "$INIT_PATH"
