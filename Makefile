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


chroot: bin/rootfs
	sudo systemd-nspawn -M alpine -D $^ --bind=$(CURDIR):/mnt


bin/rootfs:
	mkdir -p $@
	-tar xvzf $(ROOTFS) -C $@
	sudo systemd-nspawn -M alpine -D $@ apk add --update alpine-sdk perl xz-dev



clean:
	@for dir in $(VENDORS); do \
        $(MAKE) -C $$dir clean; \
    done
	@sudo rm -rf bin/*
