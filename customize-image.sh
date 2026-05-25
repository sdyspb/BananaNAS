#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

# overlays="smarc3588-i2c smarc3588-gmacs smarc3588-hdmi smarc3588-uarts smarc3588-dis smarc3588-spi smarc3588-i2s smarc3588-pcie2 smarc3588-pcie3 smarc3588-can smarc3588-usb smarc3588-sd smarc3588-leds smarc3588-exp rk3588-gpio1-a4-button"
# overlays="pixelnas-i2c pixelnas-exp pixelnas-gpio-button rk3568-sata-fbs"
overlays="armsom-sige7-pcie-split"

Main() {
	case $RELEASE in
		*)
			echo -e "\033[32m*** PixelNAS overlay integration ***\033[0m"
			mkdir -p ${SDCARD}/boot/overlay-user
			for overlay in $overlays; do
    				cp "/tmp/overlay/${overlay}.dts" "${SDCARD}/boot/overlay-user/"
    				dtc -@ -O dtb -o "${SDCARD}/boot/overlay-user/${overlay}.dtbo" \
        			"${SDCARD}/boot/overlay-user/${overlay}.dts"
			done

			if grep -q "^user_overlays=" /boot/armbianEnv.txt; then
				sed -i "/^user_overlays=/s/\$/ ${overlays}/" /boot/armbianEnv.txt
			else
				echo "user_overlays=${overlays}" >> /boot/armbianEnv.txt
			fi

			echo -e "\033[32marmbianEnv.txt content after modification:\033[0m"
			cat /boot/armbianEnv.txt

			# SetupDisplay
			
			SetHostname

			# FixConsoleNumber

			InstallToilet
		;;
	esac
} # Main

SetupDisplay() {
			echo "Compiling ip_display..."

			cp "/tmp/overlay/ip_display.c" "${SDCARD}/tmp/"
			chroot "$(pwd)" /bin/bash -c "cd /tmp && gcc -static -O2 -o ip_display ip_display.c && mv ip_display /usr/local/bin/"

			echo "Installing systemd unit..."
			cp "/tmp/overlay/ip-display.service" "${SDCARD}/etc/systemd/system/"

			echo "Enabling ip display service..."
			chroot "$(pwd)" /bin/bash -c "systemctl enable ip-display.service"

			rm -f "${SDCARD}/tmp/ip_display.c"


			echo "Compiling ups_display..."

			cp "/tmp/overlay/ups_display.c" "${SDCARD}/tmp/"
			chroot "$(pwd)" /bin/bash -c "cd /tmp && gcc -static -O2 -o ups_display ups_display.c && mv ups_display /usr/local/bin/"

			echo "Installing systemd unit..."
			cp "/tmp/overlay/ups-display.service" "${SDCARD}/etc/systemd/system/"

			echo "Enabling ups display service..."
			chroot "$(pwd)" /bin/bash -c "systemctl enable ups-display.service"

			rm -f "${SDCARD}/tmp/ups_display.c"
} # SetupDisplay

FixConsoleNumber() {
ENV_FILE="/boot/armbianEnv.txt"
if [ -f "$ENV_FILE" ]; then
    PARAM="fbcon=map:1"
    if grep -q "^extraargs=" "$ENV_FILE"; then
        # Get current extraargs value
        CURRENT=$(grep "^extraargs=" "$ENV_FILE" | cut -d= -f2-)
        # Check if the parameter is already present
        if ! echo "$CURRENT" | grep -q "$PARAM"; then
            # Append new parameter with a space
            NEW_EXTRAARGS="$CURRENT $PARAM"
            sed -i "s|^extraargs=.*|extraargs=$NEW_EXTRAARGS|" "$ENV_FILE"
            echo "Added $PARAM to existing extraargs."
        else
            echo "$PARAM already present in extraargs."
        fi
    else
        # No extraargs line, create it
        echo "extraargs=$PARAM" >> "$ENV_FILE"
        echo "Created extraargs line with $PARAM."
    fi
else
    echo "File $ENV_FILE not found, skipping kernel parameter addition."
fi
} # FixConsoleNumber

SetHostname() {
#!/bin/bash

# NEW_HOSTNAME="pixelnas"
NEW_HOSTNAME="banananas"

echo "$NEW_HOSTNAME" > /etc/hostname

if grep -q "^127.0.1.1" /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
else
    echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
fi
} # SetHostname

InstallToilet() {
#display_alert "Installing package for custom MotD logo" "toilet" "info"

apt-get update -qq
apt-get install -y -qq toilet

#display_alert "Applying custom MotD logo script" "userpatches/overlay" "info"

cp -R /tmp/overlay/etc /

chmod +x /etc/update-motd.d/10-header

# mv /etc/update-motd.d/10-header /etc/update-motd.d/10-header.orig

#display_alert "Custom MotD logo applied" "ok" "info"
} # InstallToilet

InstallOpenMediaVault() {
	# use this routine to create a Debian based fully functional OpenMediaVault
	# image (OMV 3 on Jessie, OMV 4 with Stretch). Use of mainline kernel highly
	# recommended!
	#
	# Please note that this variant changes Armbian default security 
	# policies since you end up with root password 'openmediavault' which
	# you have to change yourself later. SSH login as root has to be enabled
	# through OMV web UI first
	#
	# This routine is based on idea/code courtesy Benny Stark. For fixes,
	# discussion and feature requests please refer to
	# https://forum.armbian.com/index.php?/topic/2644-openmediavault-3x-customize-imagesh/

	echo root:openmediavault | chpasswd
	rm /root/.not_logged_in_yet
	. /etc/default/cpufrequtils
	export LANG=C LC_ALL="en_US.UTF-8"
	export DEBIAN_FRONTEND=noninteractive
	export APT_LISTCHANGES_FRONTEND=none

	case ${RELEASE} in
		jessie)
			OMV_Name="erasmus"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all3.deb"
			;;
		stretch)
			OMV_Name="arrakis"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all4.deb"
			;;
	esac

	# Add OMV source.list and Update System
	cat > /etc/apt/sources.list.d/openmediavault.list <<- EOF
	deb https://openmediavault.github.io/packages/ ${OMV_Name} main
	## Uncomment the following line to add software from the proposed repository.
	deb https://openmediavault.github.io/packages/ ${OMV_Name}-proposed main
	
	## This software is not part of OpenMediaVault, but is offered by third-party
	## developers as a service to OpenMediaVault users.
	# deb https://openmediavault.github.io/packages/ ${OMV_Name} partner
	EOF

	# Add OMV and OMV Plugin developer keys, add Cloudshell 2 repo for XU4
	if [ "${BOARD}" = "odroidxu4" ]; then
		add-apt-repository -y ppa:kyle1117/ppa
		sed -i 's/jessie/xenial/' /etc/apt/sources.list.d/kyle1117-ppa-jessie.list
	fi
	mount --bind /dev/null /proc/mdstat
	apt-get update
	apt-get --yes --force-yes --allow-unauthenticated install openmediavault-keyring
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7AA630A1EDEE7D73
	apt-get update

	# install debconf-utils, postfix and OMV
	HOSTNAME="${BOARD}"
	debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}"
	debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		debconf-utils postfix
	# move newaliases temporarely out of the way (see Ubuntu bug 1531299)
	cp -p /usr/bin/newaliases /usr/bin/newaliases.bak && ln -sf /bin/true /usr/bin/newaliases
	sed -i -e "s/^::1         localhost.*/::1         ${HOSTNAME} localhost ip6-localhost ip6-loopback/" \
		-e "s/^127.0.0.1   localhost.*/127.0.0.1   ${HOSTNAME} localhost/" /etc/hosts
	sed -i -e "s/^mydestination =.*/mydestination = ${HOSTNAME}, localhost.localdomain, localhost/" \
		-e "s/^myhostname =.*/myhostname = ${HOSTNAME}/" /etc/postfix/main.cf
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		openmediavault

	# install OMV extras, enable folder2ram and tweak some settings
	FILE=$(mktemp)
	curl "$OMV_EXTRAS_URL" -fLso "$FILE" && dpkg -i "$FILE"
	
	/usr/sbin/omv-update
	# Install flashmemory plugin and netatalk by default, use nice logo for the latter,
	# tweak some OMV settings
	. /usr/share/openmediavault/scripts/helper-functions
	apt-get -y -q install openmediavault-netatalk openmediavault-flashmemory
	AFP_Options="mimic model = Macmini"
	SMB_Options="min receivefile size = 16384\nwrite cache size = 524288\ngetwd cache = yes\nsocket options = TCP_NODELAY IPTOS_LOWDELAY"
	xmlstarlet ed -L -u "/config/services/afp/extraoptions" -v "$(echo -e "${AFP_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/smb/extraoptions" -v "$(echo -e "${SMB_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/flashmemory/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/permitrootlogin" -v "0" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/ntp/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "UTC" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/network/dns/hostname" -v "${HOSTNAME}" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/monitoring/perfstats/enable" -v "0" /etc/openmediavault/config.xml
	echo -e "OMV_CPUFREQUTILS_GOVERNOR=${GOVERNOR}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MINSPEED=${MIN_SPEED}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MAXSPEED=${MAX_SPEED}" >>/etc/default/openmediavault
	for i in netatalk samba flashmemory ssh ntp timezone interfaces cpufrequtils monit collectd rrdcached ; do
		/usr/sbin/omv-mkconf $i
	done
	/sbin/folder2ram -enablesystemd || true
	sed -i 's|-j /var/lib/rrdcached/journal/ ||' /etc/init.d/rrdcached

	# Fix multiple sources entry on ARM with OMV4
	sed -i '/stretch-backports/d' /etc/apt/sources.list

	# rootfs resize to 7.3G max and adding omv-initsystem to firstrun -- q&d but shouldn't matter
	echo 15500000s >/root/.rootfs_resize
	sed -i '/systemctl\ disable\ armbian-firstrun/i \
	mv /usr/bin/newaliases.bak /usr/bin/newaliases \
	export DEBIAN_FRONTEND=noninteractive \
	sleep 3 \
	apt-get install -f -qq python-pip python-setuptools || exit 0 \
	pip install -U tzupdate \
	tzupdate \
	read TZ </etc/timezone \
	/usr/sbin/omv-initsystem \
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "${TZ}" /etc/openmediavault/config.xml \
	/usr/sbin/omv-mkconf timezone \
	lsusb | egrep -q "0b95:1790|0b95:178a|0df6:0072" || sed -i "/ax88179_178a/d" /etc/modules' /usr/lib/armbian/armbian-firstrun
	sed -i '/systemctl\ disable\ armbian-firstrun/a \
	sleep 30 && sync && reboot' /usr/lib/armbian/armbian-firstrun

	# add USB3 Gigabit Ethernet support
	echo -e "r8152\nax88179_178a" >>/etc/modules

	# Special treatment for ODROID-XU4 (and later Amlogic S912, RK3399 and other big.LITTLE
	# based devices). Move all NAS daemons to the big cores. With ODROID-XU4 a lot
	# more tweaks are needed. CS2 repo added, CS1 workaround added, coherent_pool=1M
	# set: https://forum.odroid.com/viewtopic.php?f=146&t=26016&start=200#p197729
	# (latter not necessary any more since we fixed it upstream in Armbian)
	case ${BOARD} in
		odroidxu4)
			HMP_Fix='; taskset -c -p 4-7 $i '
			# Cloudshell stuff (fan, lcd, missing serials on 1st CS2 batch)
			echo "H4sIAKdXHVkCA7WQXWuDMBiFr+eveOe6FcbSrEIH3WihWx0rtVbUFQqCqAkYGhJn
			tF1x/vep+7oebDfh5DmHwJOzUxwzgeNIpRp9zWRegDPznya4VDlWTXXbpS58XJtD
			i7ICmFBFxDmgI6AXSLgsiUop54gnBC40rkoVA9rDG0SHHaBHPQx16GN3Zs/XqxBD
			leVMFNAz6n6zSWlEAIlhEw8p4xTyFtwBkdoJTVIJ+sz3Xa9iZEMFkXk9mQT6cGSQ
			QL+Cr8rJJSmTouuuRzfDtluarm1aLVHksgWmvanm5sbfOmY3JEztWu5tV9bCXn4S
			HB8RIzjoUbGvFvPw/tmr0UMr6bWSBupVrulY2xp9T1bruWnVga7DdAqYFgkuCd3j
			vORUDQgej9HPJxmDDv+3WxblBSuYFH8oiNpHz8XvPIkU9B3JVCJ/awIAAA==" \
			| tr -d '[:blank:]' | base64 --decode | gunzip -c >/usr/local/sbin/cloudshell2-support.sh
			chmod 755 /usr/local/sbin/cloudshell2-support.sh
			apt install -y i2c-tools odroid-cloudshell cloudshell2-fan
			sed -i '/systemctl\ disable\ armbian-firstrun/i \
			lsusb | grep -q -i "05e3:0735" && sed -i "/exit\ 0/i echo 20 > /sys/class/block/sda/queue/max_sectors_kb" /etc/rc.local \
			/usr/sbin/i2cdetect -y 1 | grep -q "60: 60" && /usr/local/sbin/cloudshell2-support.sh' /usr/lib/armbian/armbian-firstrun
			;;
		bananapim3)
			HMP_Fix='; taskset -c -p 4-7 $i '
			;;
		edge*|ficus|firefly-rk3399|nanopct4|nanopim4|nanopineo4|renegade-elite|roc-rk3399-pc|rockpro64|station-p1)
			HMP_Fix='; taskset -c -p 4-5 $i '
			;;
	esac
	echo "* * * * * root for i in \`pgrep \"ftpd|nfsiod|smbd|afpd|cnid\"\` ; do ionice -c1 -p \$i ${HMP_Fix}; done >/dev/null 2>&1" \
		>/etc/cron.d/make_nas_processes_faster
	chmod 600 /etc/cron.d/make_nas_processes_faster

	# add SATA port multiplier hint if appropriate
	[ "${LINUXFAMILY}" = "sunxi" ] && \
		echo -e "#\n# If you want to use a SATA PM add \"ahci_sunxi.enable_pmp=1\" to bootargs above" \
		>>/boot/boot.cmd

	# Filter out some log messages
	echo ':msg, contains, "do ionice -c1" ~' >/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "action " ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "netsnmp_assert" ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "Failed to initiate sched scan" ~' >>/etc/rsyslog.d/omv-armbian.conf

	# Fix little python bug upstream Debian 9 obviously ignores
	if [ -f /usr/lib/python3.5/weakref.py ]; then
		GITREF="9cd7e17640a49635d1c1f8c2989578a8fc2c1de6"
		curl -fLo /usr/lib/python3.5/weakref.py \
			"https://raw.githubusercontent.com/python/cpython/${GITREF}/Lib/weakref.py"
	fi

	# clean up and force password change on first boot
	umount /proc/mdstat
	chage -d 0 root
} # InstallOpenMediaVault

UnattendedStorageBenchmark() {
	# Function to create Armbian images ready for unattended storage performance testing.
	# Useful to use the same OS image with a bunch of different SD cards or eMMC modules
	# to test for performance differences without wasting too much time.

	rm /root/.not_logged_in_yet

	apt-get -qq install time

	curl -fLso /usr/local/bin/sd-card-bench.sh "https://raw.githubusercontent.com/ThomasKaiser/sbc-bench/master/sd-card-bench.sh"
	chmod 755 /usr/local/bin/sd-card-bench.sh

	sed -i '/^exit\ 0$/i \
	/usr/local/bin/sd-card-bench.sh &' /etc/rc.local
} # UnattendedStorageBenchmark

InstallAdvancedDesktop()
{
	apt-get install -yy transmission libreoffice libreoffice-style-tango meld remmina thunderbird kazam avahi-daemon
	[[ -f /usr/share/doc/avahi-daemon/examples/sftp-ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/sftp-ssh.service /etc/avahi/services/
	[[ -f /usr/share/doc/avahi-daemon/examples/ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/ssh.service /etc/avahi/services/
	apt clean
} # InstallAdvancedDesktop

Main "$@"
