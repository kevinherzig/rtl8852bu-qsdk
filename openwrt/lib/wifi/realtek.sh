#!/bin/sh

detect_realtek() {
	# Only run if the module is loaded
	[ -d /sys/module/8852bu ] || return 0

	for dev in /sys/class/net/*/device; do
		[ -e "$dev" ] || continue
		local ifname="${dev%/device}"
		ifname="${ifname##*/}"

		# Must be wireless
		[ -e "/sys/class/net/$ifname/wireless" ] || continue

		# Skip Qualcomm interfaces
		local driver
		driver=$(readlink "/sys/class/net/$ifname/device/driver" 2>/dev/null)
		driver="${driver##*/}"
		case "$driver" in
			*qca*|*ath*|*cnss*) continue ;;
		esac

		local macaddr
		macaddr=$(cat "/sys/class/net/$ifname/address" 2>/dev/null)

		# Check if already configured
		uci -q get wireless.radio_rtk.type >/dev/null 2>&1 && return 0

		local dev_path
		dev_path=$(readlink -f "/sys/class/net/$ifname/device" 2>/dev/null)

		uci -q batch <<-EOF
			set wireless.radio_rtk=wifi-device
			set wireless.radio_rtk.type='realtek'
			set wireless.radio_rtk.path='$dev_path'
			set wireless.radio_rtk.macaddr='$macaddr'
			set wireless.radio_rtk.disabled='1'

			set wireless.sta_rtk=wifi-iface
			set wireless.sta_rtk.device='radio_rtk'
			set wireless.sta_rtk.mode='sta'
			set wireless.sta_rtk.network='wwan'
			set wireless.sta_rtk.ssid='YourSSID'
			set wireless.sta_rtk.key='YourPassword'
			set wireless.sta_rtk.encryption='psk2'
		EOF

		uci commit wireless
		return 0
	done
}

detect_realtek
