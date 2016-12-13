VENDORS = vendor/darkhttpd vendor/ipxe/src

.PHONY: vendors $(VENDORS) clean

vendors: $(VENDORS)

vendor/ipxe/src:
	$(MAKE) -C $@ bin/ipxe.usb EMBED=../../../utils/ipxelinux.0

vendor/darkhttpd:
	$(MAKE) -C $@


clean:
	@for dir in $(VENDORS); do \
        $(MAKE) -C $$dir clean; \
    done
