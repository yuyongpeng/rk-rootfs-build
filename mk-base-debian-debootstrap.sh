#!/bin/bash
###########################
# 只能在ubuntu环境下使用
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
mkdir ${TARGET_ROOTFS_DIR}

# 安装 Debian rootfs
sudo debootstrap --arch ${ARCH} --keyring=/usr/share/keyrings/debian-archive-keyring.gpg --verbose --foreign stretch ${TARGET_ROOTFS_DIR} ${DEBIAN_SOFTWARE_SOURCE}
sudo cp /usr/bin/qemu-arm-static ${TARGET_ROOTFS_DIR}/usr/bin
sudo DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C chroot  ${TARGET_ROOTFS_DIR}  debootstrap/debootstrap --second-stage

# dphots的驱动 copy 到/system目录
mkdir -p ${TARGET_ROOTFS_DIR}/system/etc/firmware/
cp dphotos-firmware/* ${TARGET_ROOTFS_DIR}/system/etc/firmware/

# 安装系统需要的软件
cat <<EOF | sudo chroot ${TARGET_ROOTFS_DIR}

# 安装基础软件
apt-get install psmisc rfkill

# 必须要安装xserver-xorg,否则xinit没法启动 xinit chromium --no-sandbox 
apt-get install xinit xserver-xorg

# bluez
apt-get install bluez 

# wifi wpasupplicant
apt-get install wpasupplicant
wpa_passphrase hard-chain-6G hard-chain2017 > /etc/wpa_supplicant/wpa.conf
# /sbin/wpa_supplicant -i wlan0 -Dnl80211 -c /etc/wpa_supplicant/wpa.conf -C /var/run/wpa_supplicant -P /var/run/wpa.id -P /var/run/wpa.id &

EOF
# 压缩备份
rm -rf debian-init-rootfs.tar.gz
tar zcf debian-init-rootfs.tar.gz ./${TARGET_ROOTFS_DIR}