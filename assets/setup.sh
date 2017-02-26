#!/bin/bash
set -xe

export DEBIAN_FRONTEND="noninteractive"

APT_OPTIONS=$(cat <<EOF
-o Acquire::Retries=10
-o Dpkg::Options::=--force-confdef
-o Dpkg::Options::=--force-confold
--allow-downgrades --allow-remove-essential --allow-change-held-packages
-y
EOF)

# https://jpetazzo.github.io/2013/10/06/policy-rc-d-do-not-start-services-automatically/
echo exit 101 > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

# fix some issues with with gpg
apt-get $APT_OPTIONS remove gnupg && apt-get update && apt-get $APT_OPTIONS install gnupg2

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
	"A6616109451BBBF2" "A040830F7FAC5991" "1397BC53640DB551" "5A7D1D38BEB6D886"

dpkg --add-architecture i386

apt-get update && apt-get $APT_OPTIONS dist-upgrade

declare packages=(
	"linux-image-amd64" "locales"
	"git" "tig" "zsh" "tmux" "ranger" "make" "apt-file" "rxvt-unicode-256color"
	"grub2" "ssh" "neovim" "steam" "automake" "autoconf" "mplayer2" "evince"
	# Python
	"python-pip" "python-dev" "ipython" "python-pip-whl"
	# Cinnamon
	"xserver-xorg" "x11-xserver-utils" "xfonts-base" "xinit"
    "lightdm-gtk-greeter" "cinnamon-core" "dmz-cursor-theme"
    "plymouth" "arc-theme" "moka-icon-theme" "fonts-cantarell"
	# "libgl1-mesa-dri" "nvidia-driver"  # not working in test env
)

declare packages_unstable=("firefox")

declare packages_pip=("pdbpp" "path.py")

debconf-set-selections <<< $(cat << EOF
keyboard-configuration  keyboard-configuration/xkb-keymap select  fr
keyboard-configuration  keyboard-configuration/compose  select  No compose key
keyboard-configuration  keyboard-configuration/modelcode  string  pc105
locales locales/default_environment_locale select en_US.UTF-8
steam      steam/purge     note
steam      steam/license   note
steam      steam/question  select I AGREE
EOF)

apt-get $APT_OPTIONS install "${packages[@]}"
apt-get $APT_OPTIONS install -t unstable "${packages_unstable[@]}"
apt-get clean # reduce heavily the size of the tarball

pip install --no-cache-dir "${packages_pip[@]}"

ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime

dpkg-reconfigure --frontend=noninteractive tzdata
dpkg-reconfigure --frontend=noninteractive locales

if ! getent passwd max; then
    useradd -s /usr/bin/zsh -g users -G sudo max
    chown -R max:users /home/max
    sudo -u max xdg-user-dirs-update
    sudo -u max vim +PluginInstall +qall
    cd /home/max/documents/development/dotfiles && sudo -u max make && cd -
    trap "passwd max" EXIT
fi

# https://github.com/horst3180/arc-icon-theme
git clone https://github.com/horst3180/arc-icon-theme --depth 1 \
	&& cd arc-icon-theme \
	&& ./autogen.sh --prefix=/usr \
	&& make install \
	&& cd - \
	&& rm -rf arc-icon-theme

rm /usr/sbin/policy-rc.d
