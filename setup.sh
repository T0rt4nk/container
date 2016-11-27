#!/usr/bin/env bash
set -xe

declare apt_options="-o Acquire::Retries=10 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold --force-yes -y"
export DEBIAN_FRONTEND="noninteractive"

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A6616109451BBBF2
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A040830F7FAC5991
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1397BC53640DB551

dpkg --add-architecture i386

apt-get update && apt-get ${apt_options[@]} dist-upgrade

declare packages=(
	"locales" "git" "tig" "zsh" "tmux" "ranger" "make" "apt-file" "rxvt-unicode-256color"
	"google-chrome-stable" "grub" "ssh"
	# "steam" not working right now removing
	# Python
	"python-dev" "ipython" "python-pip" "python-distlib-whl"
	# Cinnamon
	"xserver-xorg" "x11-xserver-utils" "xfonts-base" "xinit"
    "lightdm-gtk-greeter" "cinnamon-core" "libgl1-mesa-dri" "dmz-cursor-theme"
    "nvidia-driver"
)
declare packages_unstable=(
	"libmsgpackc2" "neovim" "virtualenv" "libtinfo5:i386"
)

apt-get ${apt_options[@]} install -t unstable "${packages_unstable[@]}"

debconf-set-selections <<< "keyboard-configuration  keyboard-configuration/xkb-keymap select  fr"
debconf-set-selections <<< "keyboard-configuration  keyboard-configuration/compose  select  No compose key"
debconf-set-selections <<< "keyboard-configuration  keyboard-configuration/modelcode  string  pc105"

debconf-set-selections <<< "steam   steam/license   note"
debconf-set-selections <<< "steam   steam/purge     note"
debconf-set-selections <<< "steam   steam/question  select  I AGREE"

debconf-set-selections <<< "locales locales/default_environment_locale select en_US.UTF-8"

apt-get ${apt_options[@]} install "${packages[@]}"


declare packages_pip=("pdbpp" "path.py")
pip install "${packages_pip[@]}"

ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
locale-gen
dpkg-reconfigure --frontend=noninteractive tzdata
dpkg-reconfigure --frontend=noninteractive locales

if ! getent passwd max; then
	useradd -s /usr/bin/zsh -g users -G sudo max
	chown -R max:users /home/max
	sudo -u max xdg-user-dirs-update
	sudo -u max vim +PluginInstall +qall
	trap "passwd max" EXIT
fi
