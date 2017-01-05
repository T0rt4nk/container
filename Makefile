VENDORS = vendor/darkhttpd vendor/ipxe/src vendor/apk-tools

.PHONY: vendors $(VENDORS) clean


vendors: $(VENDORS)

vendor/ipxe/src:
	$(MAKE) -C $@ bin/ipxe.usb EMBED=../../../utils/ipxelinux.0

vendor/darkhttpd:
	$(MAKE) -C $@

vendor/apk-tools:
	$(MAKE) -C $@

vendor/alpine-iso:
	abuild-keygen -i
	$(MAKE) -C $@


chroot: bin/alpine
	sudo systemd-nspawn -M alpine -D $^ --bind=$(CURDIR):/mnt


bin/alpine:
	mkdir -p $@
	-tar xvzf $(ROOTFS) -C $@
	wget -O - "https://quay.io/c1/aci/quay.io/coreos/alpine-sh/latest/aci/linux/amd64" | \
        	tar --one-top-level="$@" --transform="s|rootfs/|/|" -xzf -
        sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk perl xz-dev



clean:
	@for dir in $(VENDORS); do \
        $(MAKE) -C $$dir clean; \
    done
	@sudo rm -rf bin/*
