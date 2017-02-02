.PHONY: clean

ISO = vendor/alpine-iso

PROFILE = $(ISO)/alpine-pxe

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
	abuild-keygen -ina
	fakeroot $(MAKE_ALPINE)
	@touch $(KERNEL) # update the modify time to avoid recompilation

$(INITFS) $(KERNEL): $(PROFILE).conf.mk $(PROFILE).packages
	@CMD="$(MAKE) -C /mnt _alpine-pxe" $(MAKE) chroot

chroot: bin/alpine
	@sudo systemd-nspawn -M alpine -D $^ --bind=$(CURDIR):/mnt $(CMD)

bin/alpine:
	mkdir -p $@
	wget -O - "https://quay.io/c1/aci/quay.io/coreos/alpine-sh/latest/aci/linux/amd64" | \
		tar -C "$@" --transform="s|rootfs/|/|" -xzf -
	sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk openssl-dev

$(DATA): $(INITFS) $(KERNEL)
	@mkdir -p bin/data
	@ln -sf $(CURDIR)/$(dir $<)$(notdir $@) $@

bin/data: $(DATA)

serve: vendor/darkhttpd/darkhttpd_ bin/data
	$(word 1,$^) $(word 2,$^) --port 5050

clean:
	@sudo rm -rf bin/*
	@sudo $(MAKE_ALPINE) clean 2> /dev/null
	@for dir in vendor/ipxe/src vendor/darkhttpd; do \
		$(MAKE) -C $$dir clean; \
	done

run.virsh: vendor/ipxe/src/bin/ipxe.iso clean.virsh clean.volumes bin/data
	virt-install --name ipxe --memory 1024 --virt-type kvm \
		--cdrom $< --disk size=10

clean.virsh:
	virsh list | awk '$$2 ~ /ipxe/ {system("virsh destroy " $$2)}'
	virsh list --all | awk '$$2 ~ /ipxe/ {system("virsh undefine " $$2)}'

clean.volumes:
	virsh vol-list default | awk \
		'NR > 2 && NF > 0 {system("xargs virsh vol-delete --pool default " $$1)}'
