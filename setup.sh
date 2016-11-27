#!/usr/bin/env bash
set -xe

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 302F0738F465C1535761F965A6616109451BBBF2
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A040830F7FAC5991
dpkg --add-architecture i386
apt-get update && apt-get --force-yes -y dist-upgrade

declare packages=(
	"locales" "git" "tig" "zsh" "tmux" "ranger" "make" "apt-file" "rxvt-unicode-256color"
	"google-chrome-stable" "steam"
	# Python
	"python-dev" "ipython" "python-pip" "python-distlib-whl"
)
declare packages_unstable=(
	"libmsgpackc2" "neovim" "virtualenv" "libtinfo5:i386"
)

apt-get install -t unstable --force-yes -y "${packages_unstable[@]}"
apt-get install --force-yes -y "${packages[@]}"


declare packages_pip=("pdbpp" "path.py")
pip install "${packages_pip[@]}"

ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
dpkg-reconfigure --frontend=noninteractive tzdata

locale-gen
debconf-set-selections <<< 'locales locales/default_environment_locale select en_US.UTF-8'
dpkg-reconfigure --frontend=noninteractive locales
if ! getent passwd max; then
	useradd -s /usr/bin/zsh -g users -G sudo max
	chown -R max:users /home/max
	sudo -u max xdg-user-dirs-update
	trap "passwd max" EXIT
fi
