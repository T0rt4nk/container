#!/usr/bin/env bash
ROOTFS=

init () {
	ROOTFS="$1"
	sudo -v
	[[ "$DEBUG" ]] || trap "sudo rm -rf $ROOTFS" ERR
	trap "echo $ROOTFS" EXIT
}

debootstrap () {
	init "$(mktemp -d "${TMPDIR:-/var/tmp}/debian-tortank-XXXXXX")"
	sudo debootstrap --arch=amd64 jessie "$ROOTFS" "http://httpredir.debian.org/debian"
}

setup () {
	init "$1"
	declare dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	sudo rsync -a "$dir/root/" "$ROOTFS/"
	sudo cp setup.sh "$ROOTFS/tmp/setup.sh"
	sudo systemd-nspawn -D "$ROOTFS" /tmp/setup.sh
}

build () {
	debootstrap
	setup "$ROOTFS"
}

main() {
	set -eo pipefail; [[ "$DEBUG" ]] && set -x
	declare cmd="$1"
	case "$cmd" in
		debootstrap)	shift;	debootstrap "$@";;
		setup)			shift;	setup "$@";;
		*)				build "$@";;
	esac
}

main "$@"
