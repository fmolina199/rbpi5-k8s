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

help_message()
{
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

cd $BASEDIR
if [ "$GIT_PULL" -eq "1" ]; then
	echo "=> Updateing repo..."
	git pull
fi

# Download files
cd bin
echo "=>Cleaning bin folder..."
rm -rf *.gz *.tgz *.xz "*.$MARCH"

echo "=> Downloading binaries..."
curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/libpathrs-$LIBPATHRS_VERSION.tar.xz"
curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/libseccomp-$LIBSECCOMP_VERSION.tar.gz"
curl -fSLO "https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.$MARCH"
curl -fSLO "https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-2.3.5-linux-$MARCH.tar.gz"
curl -fSLO https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-$MARCH-v1.9.1.tgz
curl -fSLO https://github.com/containerd/nerdctl/releases/download/v2.3.5/nerdctl-2.3.5-linux-$MARCH.tar.gz
curl -fSLO https://github.com/moby/buildkit/releases/download/v0.33.0/buildkit-v0.33.0.linux-$MARCH.tar.gz

echo "=> Moving binaries..."

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
