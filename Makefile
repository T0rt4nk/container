.PHONY: clean serve

BRIDGE_IP = 192.168.122.1
SERVER_PORT ?= 5050
ARCH ?= amd64

ISO = vendor/alpine-iso

PROFILE = $(ISO)/alpine-pxe

DATA_DIR = bin/data
ALPINE_REPO = "rsync://rsync.alpinelinux.org/alpine/v3.2/main/x86_64"
DEBIAN_REPO = "http://ftp.nl.debian.org/debian"
RSYNC = rsync --archive --update --hard-links --delete --info=progress2 \
        --delete-after --delay-updates --timeout=600 --human-readable --no-motd

APK_OPTS = --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories
APK_FETCH_STDOUT = apk fetch $(APK_OPTS) --stdout --quiet

NO_ECHO = >/dev/null 2>/dev/null

INITFS = $(DATA_DIR)/initramfs-grsec
KERNEL = $(DATA_DIR)/vmlinuz-grsec
MAKE_ALPINE = $(MAKE) -C $(ISO) PROFILE=alpine-pxe

all: ipxe darkhttpd $(INITFS) $(KERNEL)

ipxe: vendor/ipxe/src/bin/ipxe.iso # alias

vendor/ipxe/src/bin/ipxe.iso: assets/ipxelinux.0
	$(MAKE) -C vendor/ipxe/src bin/ipxe.iso EMBED=$(CURDIR)/assets/ipxelinux.0

darkhttpd: vendor/darkhttpd/darkhttpd_ # alias

vendor/darkhttpd/darkhttpd_:
	$(MAKE) -C $(dir $@)

_kernel: # indirection target BEWARE: use this with caution
	@$(APK_FETCH_STDOUT) linux-grsec | \
		tar -C /mnt/$(DATA_DIR) --transform="s|boot/|/|" -xz boot/vmlinuz-grsec \
		$(NO_ECHO)

INITFS_TMP	= bin/tmp.initfs
_initfs: assets/init.sh # indirection target BEWARE: use this with caution
	apk update
	abuild-keygen -ina
	apk add $(APK_OPTS) \
		--initdb \
		--update \
		--no-script \
		--root $(INITFS_TMP) \
		linux-grsec linux-firmware dahdi-linux alpine-base acct mdadm
	mkinitfs -F "ata base bootchart squashfs ext2 ext3 ext4 network dhcp scsi" \
		-b $(INITFS_TMP) -o $(INITFS) -i $< -k \
		$(notdir $(wildcard $(INITFS_TMP)/lib/modules/*))
	@rm -rf $(INITFS_TMP)

$(KERNEL):
	CMD="$(MAKE) -C /mnt _kernel" $(MAKE) chroot.alpine

$(INITFS): assets/init.sh
	CMD="$(MAKE) -C /mnt _initfs" $(MAKE) chroot.alpine

chroot.tortank: bin/tortank
	@sudo systemd-nspawn -M tortank -D $< $(CMD)

bin/tortank:
	@mkdir -p $@
	@sudo /usr/sbin/debootstrap --arch=amd64 testing "$@" $(DEBIAN_REPO)

$(DATA_DIR)/tortank.tgz: bin/tortank $(shell find root -type f | sed 's/ /\\ /g')
	@sudo rsync -rltDv --exclude=".gitkeep" "root/" "$</"
	@sudo systemd-nspawn -M tortank -D "$<" /tmp/setup.sh
	@sudo tar cvzf $@ $<

chroot.alpine: bin/alpine
	@sudo systemd-nspawn -M alpine -D $^ --bind=$(CURDIR):/mnt $(CMD)

bin/alpine:
	@mkdir -p $@
	@wget -O - "https://quay.io/c1/aci/quay.io/coreos/alpine-sh/latest/aci/linux/amd64" | \
		tar -C "$@" --transform="s|rootfs/|/|" -xzf -
	@echo "http://$(BRIDGE_IP):$(SERVER_PORT)/alpine" > "$@/etc/apk/repositories"
	@sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk openssl-dev

$(DATA_DIR)/alpine:
	# https://wiki.alpinelinux.org/wiki/How_to_setup_a_Alpine_Linux_mirror
	@mkdir -p "$@"
	@$(RSYNC) $(ALPINE_REPO) "$@"

$(DATA_DIR)/setup-disk.sh: assets/setup-disk.sh
	cp $< $@

serve: vendor/darkhttpd/darkhttpd_
	@echo Serve $(DATA_DIR) on port $(SERVER_PORT)
	@$^ $(DATA_DIR) --port $(SERVER_PORT) > /dev/null &

clean:
	@sudo rm -rf bin/*
	@sudo $(MAKE_ALPINE) clean 2> /dev/null
	@for dir in vendor/ipxe/src vendor/darkhttpd; do \
		$(MAKE) -C $$dir clean; \
	done

run.virsh: vendor/ipxe/src/bin/ipxe.iso clean.virsh clean.volumes $(INITFS) $(KERNEL)
	virt-install --name ipxe --memory 1024 --virt-type kvm \
		--network bridge=virbr0 --cdrom $< --disk size=10

clean.virsh:
	virsh list | awk '$$2 ~ /ipxe/ {system("virsh destroy " $$2)}'
	virsh list --all | awk '$$2 ~ /ipxe/ {system("virsh undefine " $$2)}'

clean.volumes:
	virsh vol-list default | awk \
		'NR > 2 && NF > 0 {system("xargs virsh vol-delete --pool default " $$1)}'

test: run.virsh
