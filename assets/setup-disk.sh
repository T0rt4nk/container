#!/bin/sh

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

sleep 2

mkswap /dev/sda1
#mkfs.ext4 /dev/sda2
