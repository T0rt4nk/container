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
	sudo rsync -av --no-o --exclude=".gitkeep" "$dir/root/" "$ROOTFS/"
	sudo cp setup.sh "$ROOTFS/tmp/setup.sh"
	sudo systemd-nspawn -M tortank -D "$ROOTFS" /tmp/setup.sh
}

build () {
	debootstrap
	setup "$ROOTFS"
}

run () {
	DEBUG=1  # enforce DEBUG
	init "$1"
	sudo systemd-nspawn -M tortank -b -D "$ROOTFS"
}

main() {
	set -eo pipefail; [[ "$DEBUG" ]] && set -x
	declare cmd="$1"
	case "$cmd" in
		debootstrap)	shift;	debootstrap "$@";;
		setup)			shift;	setup "$@";;
		run)			shift;  run "$@";;
		*)				build "$@";;
	esac
}

main "$@"
