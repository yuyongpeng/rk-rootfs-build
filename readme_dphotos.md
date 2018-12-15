## Introduction
A set of shell scripts that will build GNU/Linux distribution rootfs image
for rockchip platform.

## Available Distro
* Debian Stretch (X11)

## Usage for 32bit Debian
Building a base debian system by debootstrap

    sudo mk-base-debian-debootstrap.sh

Building the rk-debian rootfs:

	TARGET_ROOTFS_DIR=init RELEASE=stretch ARCH=armhf ./mk-rootfs-stretch-dphotos.sh

Creating the ext4 image(linaro-rootfs.img):

	TARGET_ROOTFS_DIR=init ./mk-image-dphotos.sh
---

## Cross Compile for ARM Debian

[Docker + Multiarch](http://opensource.rock-chips.com/wiki_Cross_Compile#Docker)

## Package Code Base

Please apply [those patches](https://github.com/rockchip-linux/rk-rootfs-build/tree/master/packages-patches) to release code base before rebuilding!

## FAQ

1. noexec or nodev issue
/usr/share/debootstrap/functions: line 1450: ..../rootfs/ubuntu-build-service/stretch-desktop-armhf/chroot/test-dev-null: Permission denied
E: Cannot install into target '/home/foxluo/work3/rockchip/rk_linux/rk3399_linux/rootfs/ubuntu-build-service/stretch-desktop-armhf/chroot' mounted with noexec or nodev

Solution: mount -o remount,exec,dev xxx (xxx is the mount place), then rebuild it.
