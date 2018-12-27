#!/bin/bash
###########################
# 只能在ubuntu 16.04环境下使用
# auth: 俞永鹏
###########################

# 准备编译环境

# dd if=/dev/zero of=init.img  bs=1M count=0 seek=1900
# mkfs.ext4 init.img 
# sudo mount -o loop init.img init

# 安装制作过程中使用到的软件包
sudo apt-get install debootstrap 
sudo apt-get install qemu-user-static 
sudo apt-get install debian-archive-keyring

# 初始化安装Debian系统
TARGET_ROOTFS_DIR=init
DEBIAN_SOFTWARE_SOURCE="http://ftp2.cn.debian.org/debian"
ARCH=armhf
NODEJS=node-v8.11.4-linux-armv7l
DOCKER=docker-18.03.1-ce

mkdir ${TARGET_ROOTFS_DIR}

# 安装 Debian rootfs
sudo debootstrap --arch ${ARCH} --keyring=/usr/share/keyrings/debian-archive-keyring.gpg --verbose --foreign stretch ${TARGET_ROOTFS_DIR} ${DEBIAN_SOFTWARE_SOURCE}
sudo cp /usr/bin/qemu-arm-static ${TARGET_ROOTFS_DIR}/usr/bin
sudo DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C chroot  ${TARGET_ROOTFS_DIR}  debootstrap/debootstrap --second-stage

# dphots的驱动 copy 到/system目录
mkdir -p ${TARGET_ROOTFS_DIR}/system/etc/firmware/
cp dphotos-firmware/* ${TARGET_ROOTFS_DIR}/system/etc/firmware/

# nodejs
cp dphotos-software/${NODEJS}.tar.gz ${TARGET_ROOTFS_DIR}/tmp/
# docker
cp dphotos-software/${DOCKER}.tgz ${TARGET_ROOTFS_DIR}/tmp/

# 配置文件
cp -r dphotos-config ${TARGET_ROOTFS_DIR}/tmp/
sudo mount -o bind /dev ${TARGET_ROOTFS_DIR}/dev
# 安装系统需要的软件
cat <<EOF | sudo chroot ${TARGET_ROOTFS_DIR}

# 配置文件放到对应的位置
cp -r /tmp/dphotos-config/* /
systemctl enable docker.service
systemctl enable docker.socket

apt-get update

# 安装基础软件
apt-get install -y psmisc rfkill

# 安装nodejs
tar zxf /tmp/${NODEJS}.tar.gz -C /tmp/
cp -rf /tmp/${NODEJS}/* /usr/local/

# 安装docker
tar zxf /tmp/${DOCKER}.tgz -C /tmp/
cp -rf /tmp/docker/* /usr/bin/
useradd docker

# 必须要安装xserver-xorg,否则xinit没法启动 xinit chromium --no-sandbox 
apt-get install -y xinit xserver-xorg

# bluez
apt-get install -y bluez

# wifi wpasupplicant
apt-get install -y wpasupplicant
wpa_passphrase hard-chain-6G hard-chain2017 > /etc/wpa_supplicant/wpa.conf
# /sbin/wpa_supplicant -i wlan0 -Dnl80211 -c /etc/wpa_supplicant/wpa.conf -C /var/run/wpa_supplicant -P /var/run/wpa.id -P /var/run/wpa.id &

# 删除缓存文件
rm -rf /tmp/*

EOF
sudo umount ${TARGET_ROOTFS_DIR}/dev

# 压缩备份
rm -rf debian-init-rootfs.tar.gz
tar zcf debian-init-rootfs.tar.gz ./${TARGET_ROOTFS_DIR}
