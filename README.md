# RTL8852BU/RTL8832BU driver for Qualcomm QSDK 12.5
# EXPERIMENTAL - Try it but expect crashes and please leave feedback.

Patched Realtek RTL8852BU/RTL8832BU USB WiFi driver for routers running **Qualcomm QSDK 12.5** (kernel 5.4.213), such as the **GL.iNet GL-BE3600**.

I used Claude to build a copy of this driver and debug the crashes it had.  I am going to be trying it out.  If you use it expect crashes.  Leave feedback with any information and I will try to fix.

This won't work with the luci interface due to lack of features in the driver.  Maybe if there is enough interest I'll explore it.

The upstream [lwfinger/rtl8852bu](https://github.com/lwfinger/rtl8852bu) driver crashes the kernel on connect and disconnect due to incompatibilities with Qualcomm's MLO (Multi-Link Operation) backport in QSDK. This fork fixes those issues.

## Supported devices

| Router | SoC | Kernel | Status |
|--------|-----|--------|--------|
| GL.iNet GL-BE3600 | Qualcomm IPQ5332 | 5.4.213 | Working |

USB adapter: `0bda:b832` Realtek RTL8832BU 802.11ax WLAN Adapter

Should work on other QSDK 12.5 routers with the same kernel. Open an issue if you test on a different device.

## Quick install (pre-built binary)

Download `8852bu.ko` from the [Releases page](https://github.com/kevinherzig/rtl8852bu/releases).

> Your router's vermagic must match exactly: `5.4.213 SMP preempt mod_unload aarch64`.
> Check with: `modinfo /lib/modules/5.4.213/act_connmark.ko | grep vermagic`

```sh
# Copy to router
scp 8852bu.ko root@192.168.8.1:/lib/modules/5.4.213/

# Load the module
insmod 8852bu.ko rtw_power_mgnt=0 rtw_ips_mode=0

# Verify the interface appeared
ip link | grep wlan
```

## Connect to a WiFi network

Create a wpa_supplicant config on the router:

```
# /root/wpa.conf
network={
    ssid="YourSSID"
    psk="YourPassword"
    key_mgmt=WPA-PSK
}
```

Connect:

```sh
wpa_supplicant -i wlan2 -c /root/wpa.conf -B
udhcpc -i wlan2
```

## Auto-start on boot

An OpenWrt init script is included. Install it on the router:

```sh
# Copy the init script
cp openwrt/rtl8852bu.init /etc/init.d/rtl8852bu
chmod +x /etc/init.d/rtl8852bu
/etc/init.d/rtl8852bu enable

# Create the network interface for DHCP
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='wlan2'
uci commit network
```

Edit `/root/wpa.conf` with your network credentials. The driver and connection will start automatically on boot.

## Building from source

### Prerequisites (Debian/Ubuntu x86_64)

```sh
sudo apt install -y gcc-aarch64-linux-gnu build-essential bc flex bison libssl-dev libelf-dev git
```

### Prepare kernel headers

```sh
git clone --depth 1 --branch NHSS.QSDK.12.5 \
  https://git.codelinaro.org/clo/qsdk/oss/kernel/linux-ipq-5.4.git

# Copy config from router
scp root@192.168.8.1:/proc/config.gz .
gunzip config.gz
cp config linux-ipq-5.4/.config

cd linux-ipq-5.4
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_prepare

# Fix vermagic - remove trailing '+' added by git
echo "5.4.213" > include/config/kernel.release
echo '#define UTS_RELEASE "5.4.213"' > include/generated/utsrelease.h
```

Check your router's actual kernel version with `uname -r` and match the vermagic exactly.

### Build

```sh
cd /path/to/rtl8852bu
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KSRC=/path/to/linux-ipq-5.4 -j$(nproc)
```

Output: `8852bu.ko`

## What was patched

Six issues were fixed to make this driver work on QSDK 12.5:

1. **Connect/disconnect kernel crash** -- QSDK's MLO backport adds `links[]` to `cfg80211_connect_resp_params` but `__cfg80211_connect_result()` still uses `cr->bss` (NULL). Also, `cfg80211_update_link_bss()` can free `links[0].bss`, creating a use-after-free if both fields point to the same object. Fixed by calling `cfg80211_connect_done()` directly with two separate BSS references.

2. **`cfg80211_disconnected()` signature** -- QSDK adds `int link_id` parameter. Fixed by passing `0`.

3. **`stop_ap` callback signature** -- QSDK changes to `struct cfg80211_ap_settings *`. Updated to match.

4. **`cfg80211_external_auth_params` ABI mismatch** -- Kernel uses `const u8 *pmkid` (pointer) but driver uses `u8 pmkid[16]` (array). Fixed by copying fields individually instead of casting.

5. **GCC 14 build errors** -- Added `-Wno-error` flags for harmless warnings promoted to errors.

6. **`iw dev del` kernel crash** -- All out-of-tree Realtek drivers deadlock when the primary interface is deleted. Fixed by refusing deletion (`-EOPNOTSUPP`) and fixing the monitor interface rtnl_lock deadlock. See [openwrt/openwrt#13919](https://github.com/openwrt/openwrt/issues/13919).

## Known limitations

- **No LuCI/web UI integration.** QSDK routers ship only `qcawificfg80211.sh` as the wireless handler. The `mac80211.sh` handler is unavailable and incompatible with this driver. Manage the adapter via CLI only.
- **`iw dev wlan2 del` returns "not supported".** This is intentional to prevent a kernel crash. The driver does not support runtime interface deletion.
- **Power management must be disabled.** Always load with `rtw_power_mgnt=0 rtw_ips_mode=0`.

## Credits

- Original driver: [lwfinger/rtl8852bu](https://github.com/lwfinger/rtl8852bu)
- QSDK kernel source: [CodeLinaro](https://git.codelinaro.org/clo/qsdk/oss/kernel/linux-ipq-5.4)
