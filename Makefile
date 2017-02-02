.PHONY: clean bin/data


vendor/ipxe/src/bin/ipxe.iso:
	$(MAKE) -C vendor/ipxe/src bin/ipxe.iso EMBED=ipxelinux.0

vendor/darkhttpd/darkhttpd_:
	$(MAKE) -C $@

vendor/alpine-iso/isotmp.alpine-pxe:
	abuild-keygen -ina
	fakeroot $(MAKE) -C $@ PROFILE=alpine-pxe

bin/data: vendor/alpine-iso/isotmp.alpine-pxe
	mkdir -p bin/data
	ln -sf ../../$^/isofs/boot/initramfs-grsec $@
	ln -sf ../../$^/isofs/boot/vmlinuz-grsec $@


chroot: bin/alpine
	sudo systemd-nspawn -M alpine -D $^ --bind=$(CURDIR):/mnt

bin/alpine:
	mkdir -p $@
	wget -O - "https://quay.io/c1/aci/quay.io/coreos/alpine-sh/latest/aci/linux/amd64" | \
		tar -C "$@" --transform="s|rootfs/|/|" -xzf -
	sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk openssl-dev


serve: vendor/darkhttpd/darkhttpd_ bin/data
	$(word 1,$^) $(word 2,$^) --port 5050

clean:
	@for dir in $(VENDORS); do \
        $(MAKE) -C $$dir clean; \
    done
	@sudo rm -rf bin/*

run.virsh: vendor/ipxe/src/bin/ipxe.iso clean.virsh clean.volumes
	virt-install --name ipxe --memory 1024 --virt-type kvm \
		--cdrom $(word 1, $^) --disk size=10

clean.virsh:
	virsh list | awk '$$2 ~ /ipxe/ {system("virsh destroy " $$2)}'
	virsh list --all | awk '$$2 ~ /ipxe/ {system("virsh undefine " $$2)}'

clean.volumes:
	virsh vol-list default | awk \
		'NR > 2 && NF > 0 {system("xargs virsh vol-delete --pool default " $$1)}'
