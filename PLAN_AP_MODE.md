# Plan: AP Mode Support for RTL8852BU on QSDK 12.5

## Goal
Enable the RTL8852BU USB adapter to function as an access point, configurable through LuCI.

## Current State
- Driver registers `NL80211_IFTYPE_AP` as supported
- `start_ap`, `stop_ap`, `change_beacon` cfg80211 ops are implemented
- `add_station`, `del_station`, `change_station` ops exist for client management
- STA mode works end-to-end with LuCI integration via `realtek.sh` netifd handler
- `stop_ap` signature already patched for QSDK

## Steps

### Step 1: Verify prerequisites on router
- [ ] Confirm `hostapd` is installed (`which hostapd && hostapd -v`)
- [ ] Test interface type change: `iw dev wlan2 set type __ap`
- [ ] If type change crashes, investigate and fix in driver

### Step 2: Test AP mode manually
- [ ] Set interface to AP mode
- [ ] Create minimal hostapd config:
  ```
  interface=wlan2
  driver=nl80211
  ssid=TestAP
  hw_mode=a
  channel=36
  wpa=2
  wpa_passphrase=testpassword
  wpa_key_mgmt=WPA-PSK
  rsn_pairwise=CCMP
  ```
- [ ] Start hostapd: `hostapd -dd /tmp/hostapd-wlan2.conf`
- [ ] Test client association from a phone/laptop
- [ ] Test data forwarding (ping, internet access)

### Step 3: Add AP support to realtek.sh handler
- [ ] Add `for_each_interface "ap" realtek_setup_ap` in `drv_realtek_setup`
- [ ] Implement `realtek_setup_ap()`:
  - Generate hostapd config from UCI values
  - Start hostapd with `-B -P pidfile`
  - Register process with `wireless_add_process`
  - Register VIF with `wireless_add_vif`
- [ ] Add AP-relevant config options to `drv_realtek_init_device_config`:
  - `channel`, `htmode`, `txpower`
- [ ] Add AP-relevant config options to `drv_realtek_init_iface_config`:
  - `hidden`, `isolate`, `maxassoc`

### Step 4: Hostapd config generation
- [ ] Map UCI encryption values to hostapd config:
  - `psk2` -> `wpa=2, wpa_key_mgmt=WPA-PSK, rsn_pairwise=CCMP`
  - `psk` -> `wpa=1, wpa_key_mgmt=WPA-PSK, wpa_pairwise=TKIP`
  - `psk2+ccmp` -> `wpa=2, rsn_pairwise=CCMP`
  - `sae` -> `wpa=2, wpa_key_mgmt=SAE, rsn_pairwise=CCMP`
  - `none` -> no wpa settings
- [ ] Map UCI hw_mode/htmode to hostapd:
  - `hw_mode=a` for 5GHz, `hw_mode=g` for 2.4GHz
  - HT/VHT/HE capabilities from driver's wiphy

### Step 5: LuCI testing
- [ ] Create AP interface in LuCI
- [ ] Verify clients can see and connect to the AP
- [ ] Verify DHCP works (need dnsmasq on the bridge)
- [ ] Verify internet access through the AP

### Step 6: Fix QSDK-specific issues
- [ ] Verify hostapd version compatibility with driver
- [ ] Check if QSDK hostapd has custom patches that affect nl80211 AP mode
- [ ] Test WPA2 and WPA3 handshakes

## Risk Areas
- **Interface type change**: `iw dev wlan2 set type __ap` may crash — the driver's `change_virtual_intf` handler needs testing
- **hostapd version**: QSDK ships a modified hostapd that may behave differently with non-Qualcomm drivers
- **Channel control**: fullmac driver may override hostapd's channel choice
- **No simultaneous STA+AP**: the driver likely doesn't support running both modes at once
- **Bridge integration**: AP traffic needs to be bridged to the LAN — verify the driver handles bridged frames

## Dependencies
- Working `realtek.sh` netifd handler (done)
- hostapd installed on router
- Driver module loaded with AP interface type support
