#!/bin/sh
. /lib/netifd/netifd-wireless.sh

drv_realtek_init_device_config() {
	config_add_string path
	config_add_string macaddr
	config_add_string country
	config_add_boolean disabled
}

drv_realtek_init_iface_config() {
	config_add_string mode
	config_add_string ssid
	config_add_string bssid
	config_add_string 'key:wpakey'
	config_add_string encryption
	config_add_string network
}

drv_realtek_setup() {
	json_select config
	json_get_vars disabled country path macaddr
	json_select ..

	[ "$disabled" = "1" ] && return 0

	# Find the interface name from the phy
	local ifname
	ifname=$(realtek_find_ifname "$path" "$macaddr")
	[ -z "$ifname" ] && {
		wireless_setup_failed DRIVER_NOT_FOUND
		return 1
	}

	# Ensure module is loaded
	insmod 8852bu rtw_power_mgnt=0 rtw_ips_mode=0 2>/dev/null

	sleep 1
	ip link set "$ifname" up 2>/dev/null || {
		wireless_setup_failed INTERFACE_FAILED
		return 1
	}

	for_each_interface "sta" realtek_setup_sta "$ifname"

	wireless_set_up
}

realtek_setup_sta() {
	local vif="$1"
	local ifname="$2"

	json_select config
	json_get_vars ssid key encryption bssid
	json_select ..

	[ -z "$ssid" ] && return 1

	local conf="/var/run/wpa_supplicant-${ifname}.conf"
	local pid_file="/var/run/wpa_supplicant-${ifname}.pid"

	# Determine key_mgmt from encryption
	local key_mgmt="NONE"
	local psk_line=""
	case "$encryption" in
		psk2*|psk+*|psk*)
			key_mgmt="WPA-PSK"
			psk_line="    psk=\"$key\""
			;;
		sae*)
			key_mgmt="SAE"
			psk_line="    sae_password=\"$key\""
			;;
		none|open|"")
			key_mgmt="NONE"
			;;
	esac

	# Generate wpa_supplicant config
	cat > "$conf" <<EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=0

network={
    ssid="$ssid"
${psk_line:+$psk_line
}    key_mgmt=$key_mgmt
${bssid:+    bssid=$bssid
}}
EOF

	wpa_supplicant -B \
		-P "$pid_file" \
		-D nl80211 \
		-i "$ifname" \
		-c "$conf"

	local pid
	pid=$(cat "$pid_file" 2>/dev/null)
	[ -n "$pid" ] && wireless_add_process "$pid" /usr/sbin/wpa_supplicant 1 1

	wireless_add_vif "$vif" "$ifname"
}

drv_realtek_teardown() {
	json_select config
	json_get_vars path macaddr
	json_select ..

	local ifname
	ifname=$(realtek_find_ifname "$path" "$macaddr")
	[ -z "$ifname" ] && return 0

	local pid_file="/var/run/wpa_supplicant-${ifname}.pid"
	[ -f "$pid_file" ] && kill "$(cat "$pid_file")" 2>/dev/null
	rm -f "$pid_file" "/var/run/wpa_supplicant-${ifname}.conf"

	ip link set "$ifname" down 2>/dev/null
}

drv_realtek_cleanup() {
	return 0
}

realtek_find_ifname() {
	local match_path="$1"
	local match_mac="$2"

	for dev in /sys/class/net/*/device; do
		[ -e "$dev" ] || continue
		local ifname="${dev%/device}"
		ifname="${ifname##*/}"

		# Skip non-wireless interfaces
		[ -e "/sys/class/net/$ifname/wireless" ] || continue

		# Skip Qualcomm interfaces (wlan0, wlan1)
		local driver
		driver=$(readlink "/sys/class/net/$ifname/device/driver" 2>/dev/null)
		driver="${driver##*/}"
		case "$driver" in
			*qca*|*ath*|*cnss*) continue ;;
		esac

		# Match by sysfs path
		if [ -n "$match_path" ]; then
			local dev_path
			dev_path=$(readlink -f "/sys/class/net/$ifname/device" 2>/dev/null)
			[ "$dev_path" = "$match_path" ] || \
			[ "${dev_path#*$match_path}" != "$dev_path" ] && {
				echo "$ifname"
				return 0
			}
		fi

		# Match by MAC address
		if [ -n "$match_mac" ]; then
			local dev_mac
			dev_mac=$(cat "/sys/class/net/$ifname/address" 2>/dev/null)
			[ "$dev_mac" = "$match_mac" ] && {
				echo "$ifname"
				return 0
			}
		fi

		# If no match criteria, return first non-QCA wireless USB device
		if [ -z "$match_path" ] && [ -z "$match_mac" ]; then
			echo "$ifname"
			return 0
		fi
	done

	return 1
}

add_driver realtek
