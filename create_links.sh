#!/bin/bash

GIT_PULL=0

help_message()
{
	# Display Help
	echo "Create symbolic links for Raspberry PI5 K8S configuration"
	echo
	echo "Syntax: ${0} [-h|p]"
	echo "options:"
	echo "-h     Print help."
	echo "-p     Run git pull before running other links."
	echo
}

while getopts ":hp" option; do
	case $option in
		p) # Run git pull
			GIT_PULL=1;;
		h) # display Help
			help_message
			exit;;
		\?) # Invalid option
			echo "Error: Invalid option"
			echo ""
			help_message
			exit;;
   esac
done

SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

if [ "$GIT_PULL" -eq "1" ]; then
	echo "=> Updateing repo..."
	git pull
fi

if [ ! -f /etc/modules-load.d/k8s.conf ]; then
	echo "=> Creating Modules link..."
	ln -s $BASEDIR/config/modules-load.d-k8s.conf /etc/modules-load.d/k8s.conf
fi

if [ ! -f /etc/sysctl.d/k8s.conf ]; then
	echo "=> Creating Sysctl link..."
	ln -s $BASEDIR/config/sysctl.d-k8s.conf /etc/sysctl.d/k8s.conf
fi

if [ ! -f /etc/systemd/system/containerd.service ]; then
	echo "=> Creating Systemd Containerd link..."
	ln -s $BASEDIR/config/systemd-system-containerd.service /etc/systemd/system/containerd.service
fi

