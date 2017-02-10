.PHONY: clean

BRIDGE_IP = 192.168.122.1
SERVER_PORT ?= 5050
ARCH ?= amd64

ISO = vendor/alpine-iso

PROFILE = $(ISO)/alpine-pxe
ALPINE_REPO = "rsync://rsync.alpinelinux.org/alpine/v3.2/main/x86_64"
DEBIAN_REPO = "http://ftp.nl.debian.org/debian"
RSYNC = rsync --archive --update --hard-links --delete --info=progress2 \
        --delete-after --delay-updates --timeout=600 --human-readable --no-motd

INITFS = $(ISO)/isotmp.alpine-pxe/isofs/boot/initramfs-grsec
KERNEL = $(ISO)/isotmp.alpine-pxe/isofs/boot/vmlinuz-grsec

DATA = bin/data/initramfs-grsec bin/data/vmlinuz-grsec
MAKE_ALPINE = $(MAKE) -C $(ISO) PROFILE=alpine-pxe

all: ipxe darkhttpd $(INITFS) $(KERNEL)

ipxe: vendor/ipxe/src/bin/ipxe.iso # alias

vendor/ipxe/src/bin/ipxe.iso: vendor/ipxe/src/ipxelinux.0
	$(MAKE) -C vendor/ipxe/src bin/ipxe.iso EMBED=ipxelinux.0

darkhttpd: vendor/darkhttpd/darkhttpd_ # alias

vendor/darkhttpd/darkhttpd_:
	$(MAKE) -C $(dir $@)

_alpine-pxe: # indirection target BEWARE: use this with caution
	$(MAKE_ALPINE) clean
	apk update
	abuild-keygen -ina
	fakeroot $(MAKE_ALPINE) INITFS_SCRIPT=init.sh
	@touch $(KERNEL) # update the modify time to avoid recompilation

$(INITFS) $(KERNEL): $(PROFILE).conf.mk $(PROFILE).packages $(ISO)/init.sh serve.lock bin/data/alpine
	@CMD="$(MAKE) -C /mnt _alpine-pxe" $(MAKE) chroot.alpine

chroot.alpine: bin/alpine
	@sudo systemd-nspawn -M alpine -D $^ --bind=$(CURDIR):/mnt $(CMD)

chroot.tortank: bin/tortank
	@sudo systemd-nspawn -M tortank -D $< $(CMD)

bin/tortank:
	@mkdir -p $@
	@sudo /usr/sbin/debootstrap --arch=amd64 testing "$@" $(DEBIAN_REPO)

bin/tortank.tgz: bin/tortank $(shell find root -type f | sed 's/ /\\ /g')
	@sudo rsync -rltDv --exclude=".gitkeep" "root/" "$</"
	@sudo systemd-nspawn -M tortank -D "$<" /tmp/setup.sh
	@sudo tar cvzf $@ $<

bin/alpine:
	@mkdir -p $@
	@wget -O - "https://quay.io/c1/aci/quay.io/coreos/alpine-sh/latest/aci/linux/amd64" | \
		tar -C "$@" --transform="s|rootfs/|/|" -xzf -
	@echo "http://$(BRIDGE_IP):$(SERVER_PORT)/alpine" > "$@/etc/apk/repositories"
	@sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk openssl-dev

bin/data/alpine:
	# https://wiki.alpinelinux.org/wiki/How_to_setup_a_Alpine_Linux_mirror
	@mkdir -p "$@"
	@$(RSYNC) $(ALPINE_REPO) "$@"

$(DATA): $(INITFS) $(KERNEL)
	@mkdir -p bin/data
	@ln -sf $(CURDIR)/$(dir $<)$(notdir $@) $@


serve.lock: vendor/darkhttpd/darkhttpd_
	$^ bin/data --port $(SERVER_PORT) & echo $$! > $@

clean:
	@sudo rm -rf bin/*
	@sudo $(MAKE_ALPINE) clean 2> /dev/null
	@for dir in vendor/ipxe/src vendor/darkhttpd; do \
		$(MAKE) -C $$dir clean; \
	done

run.virsh: vendor/ipxe/src/bin/ipxe.iso clean.virsh clean.volumes serve.lock $(DATA)
	virt-install --name ipxe --memory 1024 --virt-type kvm \
		--network bridge=virbr0 --cdrom $< --disk size=10

clean.virsh:
	virsh list | awk '$$2 ~ /ipxe/ {system("virsh destroy " $$2)}'
	virsh list --all | awk '$$2 ~ /ipxe/ {system("virsh undefine " $$2)}'

clean.volumes:
	virsh vol-list default | awk \
		'NR > 2 && NF > 0 {system("xargs virsh vol-delete --pool default " $$1)}'

clean.serve: serve.lock
	@kill $$(cat $<)
	@rm $<

test: run.virsh clean.serve
