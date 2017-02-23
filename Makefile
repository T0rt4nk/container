.PHONY: clean serve

BRIDGE_IP = 192.168.122.1
SERVER_PORT ?= 5050

DATA_DIR = bin/data
ALPINE_REPO = "rsync://rsync.alpinelinux.org/alpine/v3.2/main/x86_64"
DEBIAN_REPO = "http://ftp.nl.debian.org/debian"

RSYNC = rsync --archive --update --hard-links --delete --info=progress2 \
        --delete-after --delay-updates --timeout=600 --human-readable --no-motd
APK_OPTS = --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories
APK_FETCH_STDOUT = apk fetch $(APK_OPTS) --stdout --quiet
NO_ECHO = >/dev/null 2>/dev/null

INITFS = $(DATA_DIR)/initramfs
KERNEL = $(DATA_DIR)/vmlinuz

all: serve ipxe darkhttpd $(INITFS) $(KERNEL)

ipxe: vendor/ipxe/src/bin/ipxe.iso # alias

vendor/ipxe/src/bin/ipxe.iso: assets/ipxelinux.0
	$(MAKE) -C vendor/ipxe/src bin/ipxe.iso EMBED=$(CURDIR)/assets/ipxelinux.0

darkhttpd: vendor/darkhttpd/darkhttpd_ # alias

bin/darkhttpd:
	$(MAKE) -C vendor/darkhttpd
	mv vendor/darkhttpd/darkhttpd_ $@

_kernel: # indirection target BEWARE: use this with caution
	@$(APK_FETCH_STDOUT) linux-vanilla | \
		tar -C /mnt/$(DATA_DIR) --transform="s|boot/|/|" -xz boot/vmlinuz \
		$(NO_ECHO)

INITFS_TMP	= bin/tmp.initfs
INITFS_KERNELSTAMP = $(INITFS_TMP)/usr/share/kernel/vanilla/kernel.release

$(INITFS_KERNELSTAMP):
	apk add $(APK_OPTS) \
		--initdb \
		--update \
		--no-script \
		--root $(INITFS_TMP) \
		linux-vanilla linux-firmware dahdi-linux alpine-base acct mdadm

_initfs: assets/init.sh $(INITFS_KERNELSTAMP) # indirection target BEWARE: use this with caution
	mkinitfs -F "ata base bootchart squashfs ext2 ext3 ext4 network dhcp scsi" \
		-b $(INITFS_TMP) -o $(INITFS) -i $< $(shell cat $(INITFS_KERNELSTAMP))
	cd $(INITFS_TMP) && rm -rf * && zcat $(CURDIR)/$(INITFS) | cpio -idmv $(NO_ECHO)
	apk add $(APK_OPTS) --initdb --update --root $(INITFS_TMP) e2fsprogs
	cd $(INITFS_TMP) && find . | cpio --quiet -o -H newc | gzip -9 > $(CURDIR)/$(INITFS)
	rm -rf $(INITFS_TMP)

$(KERNEL):
	CMD="$(MAKE) -C /mnt _kernel" $(MAKE) chroot.alpine

$(INITFS): assets/init.sh
	CMD="$(MAKE) -C /mnt _initfs" $(MAKE) chroot.alpine

chroot.tortank: bin/tortank
	@sudo systemd-nspawn -M tortank -D $< --bind=$(CURDIR):/mnt $(CMD)

bin/tortank:
	@mkdir -p $@
	@sudo /usr/sbin/debootstrap --arch=amd64 testing "$@" $(DEBIAN_REPO)

$(DATA_DIR)/tortank.tgz: bin/tortank assets/setup.sh $(shell find root -type f | sed 's/ /\\ /g')
	@sudo rsync -rltDv --exclude=".gitkeep" "root/" "$</"
	@CMD="/mnt/$(word 2,$^)" $(MAKE) chroot.tortank
	@sudo tar --transform="s|$</|/|" -cvzf $@ $<

chroot.alpine: bin/alpine
	@sudo systemd-nspawn -M alpine -D $< --bind=$(CURDIR):/mnt $(CMD)

bin/alpine: $(DATA_DIR)/alpine
	@mkdir -p $@
	@wget -O - "https://quay.io/c1/aci/quay.io/coreos/alpine-sh/latest/aci/linux/amd64" | \
		tar -C "$@" --transform="s|rootfs/|/|" -xzf -
	@echo "http://$(BRIDGE_IP):$(SERVER_PORT)/alpine" > "$@/etc/apk/repositories"
	@sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk openssl-dev tar

$(DATA_DIR)/alpine:
	# https://wiki.alpinelinux.org/wiki/How_to_setup_a_Alpine_Linux_mirror
	@mkdir -p "$@"
	@$(RSYNC) $(ALPINE_REPO) "$@"


$(DATA_DIR)/setup-disk.sh: assets/setup-disk.sh
	cp $< $@

serve: bin/darkhttpd
	@echo Serve $(DATA_DIR) on port $(SERVER_PORT)
	@-$^ $(DATA_DIR) --port $(SERVER_PORT) $(NO_ECHO) &

clean:
	@sudo rm -rf bin/*
	@for dir in vendor/ipxe/src vendor/darkhttpd; do \
		$(MAKE) -C $$dir clean; \
	done

DATA = $(INITFS) $(KERNEL) $(DATA_DIR)/setup-disk.sh $(DATA_DIR)/tortank.tgz
run.virsh: vendor/ipxe/src/bin/ipxe.iso $(DATA) clean.virsh clean.volumes
	virt-install --name ipxe --memory 1024 --virt-type kvm \
		--network=default --cdrom $< --disk size=10

clean.virsh:
	virsh list | awk '$$2 ~ /ipxe/ {system("virsh destroy " $$2)}'
	virsh list --all | awk '$$2 ~ /ipxe/ {system("virsh undefine " $$2)}'

clean.volumes:
	virsh vol-list default | awk \
		'NR > 2 && NF > 0 {system("xargs virsh vol-delete --pool default " $$1)}'

test: serve run.virsh
