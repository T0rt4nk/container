#!/bin/sh
set -x

# basic environment
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export SERVER_IP=192.168.122.1
export SERVER_PORT=5050
export MOUNT_POINT="/mnt/"

/bin/busybox mkdir -p /usr/bin /usr/sbin /proc /sys /dev /media/cdrom \
	/media/usb /tmp
/bin/busybox --install -s

# hide kernel messages
dmesg -n 1

# needed devs
[ -c /dev/null ] || mknod -m 666 /dev/null c 1 3

# basic mounts
mount -t proc -o noexec,nosuid,nodev proc /proc
mount -t sysfs -o noexec,nosuid,nodev sysfs /sys

mount -t tmpfs -o exec,nosuid,mode=0755,size=1M mdev /dev
echo "/sbin/mdev" > /proc/sys/kernel/hotplug
mdev -s
[ -d /dev/pts ] || mkdir -m 755 /dev/pts
[ -c /dev/ptmx ] || mknod -m 666 /dev/ptmx c 5 2
# make sure /dev/null is setup correctly
[ -f /dev/null ] && rm -f /dev/null
[ -c /dev/null ] || mknod -m 666 /dev/null c 1 3
mount -t devpts -o gid=5,mode=0620,noexec,nosuid devpts /dev/pts
[ -d /dev/shm ] || mkdir /dev/shm
mount -t tmpfs -o nodev,nosuid,noexec shm /dev/shm

# activate kernel modules and drivers
modprobe -a loop squashfs sd_mod 2> /dev/null
find /sys -name modalias | xargs sort -u | xargs modprobe -a 2> /dev/null
find /sys -name modalias | xargs sort -u | xargs modprobe -a 2> /dev/null

# configure network
for x in /sys/class/net/eth*
do
	echo $x
	[ -e "$x" ] && device=${x##*/} && break
done
if [ -z "$device" ]
then
	echo "ERROR: IP requested but no network device was found"
	exec sh

fi
echo "Obtaining IP via DHCP ($device)..."
ifconfig $device 0.0.0.0
udhcpc -i $device -f -q

mkdir -p "$MOUNT_POINT"
wget -O - "$SERVER_IP:$SERVER_PORT/setup-disk.sh" | sh

exec sh
