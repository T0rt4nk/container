#!/bin/sh

FSTAB="${MOUNT_POINT}/etc/fstab"

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
  +1G # 1GB swap parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  2 # bootable partition is partition 2 -- /dev/sda2
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

sync

mkswap /dev/sda1
mkfs.ext4 /dev/sda2
swapon /dev/sda1
mount -t ext4 /dev/sda2 "$MOUNT_POINT"

for DIR in dev dev/pts proc sys
do
	mkdir -p "$MOUNT_POINT/$DIR"
	mount --bind "/$DIR" "$MOUNT_POINT/$DIR"
done

wget -O - "$SERVER_IP:$SERVER_PORT/tortank.test.tgz" | \
	tar -C "$MOUNT_POINT" -xzf -

cat > "$FSTAB" << EOF
# <target name>   <source device>   <key file>   <options>
/dev/sda2         /	                ext4         defaults  0 1
EOF


chroot /mnt grub-install /dev/sda
chroot /mnt update-grub
