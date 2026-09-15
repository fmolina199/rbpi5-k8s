#!/bin/bash

set -e

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

while getopts ":hpa" option; do
	case "$option" in
		p) # Run git pull
			GIT_PULL=1
			shift
			continue
		;;
		a) # Machine arch
			MARCH="$2"
			shift 2
			continue
		;;
		h) # display Help
			help_message
			exit
		;;
		\?) # Invalid option
			echo "Invalid option: $option"
			echo ""
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


INIT_PATH=$(pwd)
SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

BUILDKIT_FILE="buildkit-v$BUILDKIT_VERSION.linux-$MARCH.tar.gz"
CNI_PLUGINS_FILE="cni-plugins-linux-$MARCH-v$CNI_PLUGINS_VERSION.tgz"
CONTAINERD_FILE="containerd-$CONTAINERD_VERSION-linux-$MARCH.tar.gz"
LIBPATHRS_FILE="libpathrs-$LIBPATHRS_VERSION.tar.xz"
LIBSECCOMP_FILE="libseccomp-$LIBSECCOMP_VERSION.tar.gz"
NERDCTL_FILE="nerdctl-$NERDCTL_VERSION-linux-$MARCH.tar.gz"

cd $BASEDIR
if [ "$GIT_PULL" -eq "1" ]; then
	echo "=> Updateing repo..."
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

echo "=> Cleaning bin folder..."
rm -rf bin

echo "=> Re-creating bin"
mkdir bin
cd bin

echo "=> Downloading binaries..."
curl -fSLO https://github.com/moby/buildkit/releases/download/v$BUILDKIT_VERSION/$BUILDKIT_FILE
curl -fSLO https://github.com/containernetworking/plugins/releases/download/v$CNI_PLUGINS_VERSION/$CNI_PLUGINS_FILE
curl -fSLO "https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/$CONTAINERD_FILE"
curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/$LIBPATHRS_FILE"
curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/$LIBSECCOMP_FILE"
curl -fSLO "https://github.com/containerd/nerdctl/releases/download/v$NERDCTL_VERSION/$NERDCTL_FILE"
curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$MARCH"

echo "=> Moving binaries..."
mkdir -p libpathrs
mv "$LIBPATHRS_FILE" libpathrs/
cd libpathrs
tar xf "$LIBPATHRS_FILE"
mv "libpathrs-$LIBPATHRS_VERSION" "$LIBPATHRS_VERSION"
rm "$LIBPATHRS_FILE"
cd ..

mkdir -p libseccomp
mv "$LIBSECCOMP_FILE" libseccomp/
cd libseccomp
tar xf "$LIBSECCOMP_FILE"
mv "libseccomp-$LIBSECCOMP_VERSION" "$LIBSECCOMP_VERSION"
rm "$LIBSECCOMP_FILE"
cd ..

mkdir -p "runc/$RUNC_VERSION"
chmod +x "runc.$MARCH"
mv "runc.$MARCH" "runc/$RUNC_VERSION"

mkdir -p containerd
mv "containerd-$CONTAINERD_VERSION-linux-$MARCH.tar.gz" containerd/
cd containerd
tar xf "$CONTAINERD_FILE"
mv "bin" "$CONTAINERD_VERSION"
rm "$CONTAINERD_FILE"
cd ..

mkdir -p "cni-plugins/$CNI_PLUGINS_VERSION"
mv "$CNI_PLUGINS_FILE" cni-plugins
cd cni-plugins
tar xf "$CNI_PLUGINS_FILE" -C "$CNI_PLUGINS_VERSION"
rm "$CNI_PLUGINS_FILE"
cd ..

mkdir -p "nerdctl/$NERDCTL_VERSION"
mv "$NERDCTL_FILE" nerdctl/
cd nerdctl
tar xf "$NERDCTL_FILE" -C "$NERDCTL_VERSION"
rm "$NERDCTL_FILE"
cd ..

mkdir buildkit
mv "$BUILDKIT_FILE" buildkit/
cd buildkit
tar xf "$BUILDKIT_FILE"
mv "bin" "$BUILDKIT_VERSION"
rm "$BUILDKIT_FILE"
cd ..

echo "=> install libpathrs..."
cd "libpathrs/$LIBPATHRS_VERSION"
make release EXTRA_RUSTC_FLAGS="-C linker=clang"
make install
cd ../..

echo "=> install libseccomp..."
cd "libseccomp/$LIBSECCOMP_VERSION"
make
make install
cd ../..



# -------- HERE
#if [ ! -f /etc/modules-load.d/k8s.conf ]; then
#	echo "=> Creating Modules link..."
#	ln -s $BASEDIR/config/modules-load.d-k8s.conf /etc/modules-load.d/k8s.conf
#fi

#if [ ! -f /etc/sysctl.d/k8s.conf ]; then
#	echo "=> Creating Sysctl link..."
#	ln -s $BASEDIR/config/sysctl.d-k8s.conf /etc/sysctl.d/k8s.conf
#fi

#if [ ! -f /etc/systemd/system/containerd.service ]; then
#	echo "=> Creating Systemd Containerd link..."
#	ln -s $BASEDIR/config/systemd-system-containerd.service /etc/systemd/system/containerd.service
#fi
cd $INIT_PATH
