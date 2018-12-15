#!/bin/bash -e

# Directory contains the target rootfs
if [ ! $TARGET_ROOTFS_DIR ]; then
  TARGET_ROOTFS_DIR="init"
fi
if [ ! RELEASE ]; then
  RELEASE="stretch"
fi
if [ ! $ARCH ]; then
	ARCH='armhf'
fi
if [ ! $VERSION ]; then
	VERSION="debug"
fi

if [ ! -e debian-init-rootfs.tar.gz ]; then
	echo -e "\033[36m Run mk-base-debian-debootstrap.sh first \033[0m"
fi

finish() {
	sudo umount $TARGET_ROOTFS_DIR/dev
	exit -1
}
trap finish ERR

# 配置文件
cp -rf dphotos-config/* ${TARGET_ROOTFS_DIR}/


echo -e "\033[36m packages 存放的是deb的安装包 \033[0m"
echo -e "\033[36m Copy overlay to rootfs \033[0m"
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages
# some configs
sudo cp -rf overlay/* $TARGET_ROOTFS_DIR/
#if [ "$ARCH" == "armhf"  ]; then
#    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_32 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
#    sudo cp overlay-firmware/usr/bin/rk_wifi_init_32 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
#fi

# bt,wifi,audio firmware
#sudo mkdir -p $TARGET_ROOTFS_DIR/system/lib/modules/
#sudo find ../kernel/drivers/net/wireless/rockchip_wlan/*  -name "*.ko" | \
#    xargs -n1 -i sudo cp {} $TARGET_ROOTFS_DIR/system/lib/modules/

# 全部都copy了，是否可以去掉？
#sudo cp -rf overlay-firmware/* $TARGET_ROOTFS_DIR/

# # adb
# if [ "$ARCH" == "armhf" ]; then
# sudo cp -rf overlay-debug/usr/local/share/adb/adbd-32 $TARGET_ROOTFS_DIR/usr/local/sbin/adbd
# sudo cp -rf overlay-debug/usr/local/share/adb/S60adbd $TARGET_ROOTFS_DIR/usr/local/sbin/
# fi

# glmark2
# if [ "$ARCH" == "armhf" ]; then
# sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/glmark2
# sudo mkdir -p $TARGET_ROOTFS_DIR/usr/local/share/glmark2
# sudo cp -rf overlay-debug/usr/local/share/glmark2/armhf/share/* $TARGET_ROOTFS_DIR/usr/local/share/glmark2
# sudo cp overlay-debug/usr/local/share/glmark2/armhf/bin/glmark2-es2 $TARGET_ROOTFS_DIR/usr/local/bin/glmark2-es2
# fi

# if [ "$VERSION" == "debug" ] || [ "$VERSION" == "jenkins" ]; then
# 	# adb, video, camera  test file
# 	sudo cp -rf overlay-debug/* $TARGET_ROOTFS_DIR/
# fi

# if [ "$VERSION" == "jenkins" ]; then
# 	# network
# 	sudo cp -b /etc/resolv.conf $TARGET_ROOTFS_DIR/etc/resolv.conf
# fi

echo -e "\033[36m Change root.....................\033[0m"
sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR

chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
apt-get update
# apt-get install -y blueman

#-------- 一些必须的软件 -----------
echo -e "\033[36m 安装一些必须的软件   033[0m"
apt-get install -y wpasupplicant ssh git

apt-get install -y  libgtk3.0-cil-dev libxss-dev libgconf-2-4 libnss3 xinput madplay bluez \
rfkill alsa-utils wireless-tools mosquitto x11-xserver-utils

# 安装混音的软件
echo -e "\033[36m 安装混音的软件  033[0m"
apt-get install -y sox libsox-fmt-all b
# 安装声音
echo -e "\033[36m 安装声音软件 pluseaudio  033[0m"
apt-get -y install pulseaudio
systemctl --system enable pulseaudio.service
echo "default-server = /var/run/pulse/native" >> /etc/pulse/client.conf
echo "autospawn = no" >> /etc/pulse/client.conf

useradd web
usermod -a -G tty web && usermod -a -G audio web && usermod -a -G video web
# 把web添加进pulse-access组，以便访问
usermod -a -G pulse-access web
usermod -a -G input web && usermod -a -G pulse web

# 去掉命令行登录界面
echo -e "\033[36m 去掉命令行登录界面  033[0m"
sed -i 's/ExecStart/#ExecStart/' /lib/systemd/system/getty@.service


# docker 配置
echo -e "\033[36m docker配置  033[0m"
systemctl --system enable docker.socket
systemctl enable docker.service
#curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/debian/gpg | apt-key add -
#sudo add-apt-repository "deb [arch=armhf] http://mirrors.aliyun.com/docker-ce/linux/debian stretch stable"
# 查看有哪些版本
#apt-cache  madison docker-ce
# 安装完成后，会占用180MB的空间，最好使用已编译好的
#apt-get install -y docker-ce=18.03.1~ce-0~debian


apt-get install -f -y
#---------------conflict workaround --------------
apt-get remove -y xserver-xorg-input-evdev

apt-get install -y libxfont1 libinput-bin libinput10 libwacom-common libwacom2 libunwind8 xserver-xorg-input-libinput

#---------------Xserver--------------
echo -e "\033[36m Setup Xserver.................... \033[0m"
dpkg -i  /packages/xserver/*
apt-get install -f -y

#---------------Mali[rk3288]--------------
echo -e "\033[36m Setup Mali.................... \033[0m"
# cat /sys/devices/platform/*gpu/gpuinfo
# Mali-T76x 4 cores r1p0 0x0750
dpkg -i  /packages/libmali/libmali-rk-midgard-t76x-r14p0-r1p0_*.deb
#dpkg -i  /packages/libmali/libmali-rk-midgard-t76x-r14p0-r0p0_*.deb
apt-get install -f -y

#---------------Video--------------
echo -e "\033[36m Setup Video.................... \033[0m"
apt-get install -y gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-alsa \
	gstreamer1.0-plugins-good  gstreamer1.0-plugins-bad alsa-utils

dpkg -i  /packages/video/mpp/librockchip-mpp1_*_armhf.deb
dpkg -i  /packages/video/mpp/librockchip-mpp-dev_*_armhf.deb
dpkg -i  /packages/video/mpp/librockchip-vpu0_*_armhf.deb
dpkg -i  /packages/video/gstreamer/*.deb
apt-get install -f -y

#---------------Qt-Video--------------
# dpkg -l | grep lxde
# if [ "$?" -eq 0 ]; then
# 	# if target is base, we won't install qt
# 	apt-get install  -y libqt5opengl5 libqt5qml5 libqt5quick5 libqt5widgets5 libqt5gui5 libqt5core5a qml-module-qtquick2 \
# 		libqt5multimedia5 libqt5multimedia5-plugins libqt5multimediaquick-p5
# 	dpkg -i  /packages/video/qt/*
# 	apt-get install -f -y
# else
# 	echo "won't install qt"
# fi

#---------------Others--------------

#----------chromium------
# dpkg -i  /packages/others/chromium/*
# sudo apt-mark hold chromium
#---------FFmpeg---------
# apt-get install -y libsdl2-2.0-0 libcdio-paranoia1 libjs-bootstrap libjs-jquery
# dpkg -i  /packages/others/ffmpeg/*
#---------FFmpeg---------
# dpkg -i  /packages/others/mpv/*
# apt-get install -f -y

#---------------Debug-------------- 
# if [ "$VERSION" == "debug" ] || [ "$VERSION" == "jenkins" ] ; then
# 	apt-get install -y sshfs openssh-server bash-completion
# fi

#---------------Custom Script-------------- 
# systemctl enable rockchip.service
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

#---------------get accelerated back for chromium v61--------------
#ln -s /usr/lib/arm-linux-gnueabihf/libGLESv2.so /usr/lib/chromium/libGLESv2.so
#ln -s /usr/lib/arm-linux-gnueabihf/libEGL.so /usr/lib/chromium/libEGL.so

#---------------Clean-------------- 
rm -rf /var/lib/apt/lists/*
rm -rf /usr/bin/qemu-arm-static

# 清理文件系统完成文件系统的制作
apt-get clean
rm -rf /packages

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
