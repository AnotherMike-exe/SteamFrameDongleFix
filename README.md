# SteamFrameDongleFix

> Stops the game stutter and desktop freezes that the Valve Steam Frame wireless adapter causes on Linux (CachyOS, Arch, and other distributions with NetworkManager).

When the Steam Frame wireless adapter (USB `28de:2432`, Realtek RTL8852CU, driver `rtw89_8852cu`) is plugged in, the PC can freeze for 10–17 s about once a minute. This happens even when you do not stream to the headset. Steam retries the headset link every 60 s. Each retry makes the adapter reinitialize over USB while the kernel holds the global network lock (RTNL), so Steam, games, Plasma and NetworkManager all wait. This project installs three small, removable workarounds and a self-test that tells you when a kernel update makes them unnecessary.

---

## Usage

Requirements: Linux with NetworkManager, systemd and udev. Kernel 7.2 or newer with `CONFIG_RTW89_DEBUGFS=y` (CachyOS and Arch kernels have it).

```bash
git clone https://github.com/AnotherMike-exe/SteamFrameDongleFix.git
cd SteamFrameDongleFix
sudo ./bin/steam-frame-dongle install
sudo steam-frame-dongle replug
sudo steam-frame-dongle status
```

Working when `status` shows:

```
  NetworkManager config loaded:   yes
  MAC address:                    permanent
  Inactive power save:            off (disable_dm 0x20)
```

After each kernel update, put the headset to sleep, close games, and run `sudo steam-frame-dongle selftest`. It tells you which workarounds are still needed. When none are needed, run `sudo steam-frame-dongle uninstall`.

Full setup is in [docs/DEV-SETUP.md](docs/DEV-SETUP.md).

## Details

The three workarounds:

1. **NetworkManager keeps the permanent MAC address** on the adapter. A MAC change forces an interface down/up, which takes 10–15 s on this chip.
2. **A udev rule turns off rtw89 inactive power save** each time the adapter appears. Without this, every scan wakes the chip, which takes about 10 s.
3. **The journal gets a 1 GB cap.** The driver logs about 20 kernel warnings per second (`WARN_ON(!sband)` in `net/mac80211/rx.c`). With a small cap, all other logs disappear within minutes.

Measured on CachyOS, kernel 7.3.0-4: the longest stall per Steam retry went from 12–17 s to about 2.7 s. KWin and Plasma stayed responsive. Commands, paths and the test method are in [docs/QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md).

Known limitations:

- A stall of about 2–3 s per retry is left. The source is the Steam retry itself ([steam-for-linux #13643](https://github.com/ValveSoftware/steam-for-linux/issues/13643)).
- The 2.4 GHz warning flood continues until the kernel fix lands. The journal cap only limits its effect.
- With inactive power save off, the adapter uses a little more power while idle.
- `selftest` causes stalls on purpose. Do not run it during a game.

Search terms: Steam Frame dongle freeze Linux, Steam Frame wireless adapter stutter, rtw89_8852cu stall, RTL8852CU NetworkManager hang, Steam Frame CachyOS, Steam Frame Arch Linux, 28de:2432.

- [Architecture](docs/ARCHITECTURE.md): root cause and design decisions
- [Dev setup](docs/DEV-SETUP.md): from a clone to a tested install
- [Quick reference](docs/QUICK-REFERENCE.md): commands, files and paths

## Attributions

- The inactive power save switch comes from the rtw89 USB series by Realtek ("wifi: rtw89: debug: disable inactive power save to reduce bus overhead", rtw-next `bd2d1abf74e4`, in Linux 7.2 and newer).
- The 2.4 GHz warning analysis comes from Nícolas Prado's patch "wifi: rtw89: Don't return default channel from disabled bands" (linux-wireless, 2026-08-12).
- Thanks to the reporters in [steam-for-linux #13643](https://github.com/ValveSoftware/steam-for-linux/issues/13643) and [morrownr/rtw89 #133](https://github.com/morrownr/rtw89/issues/133).

This project is not affiliated with Valve or Realtek. Licensed under [MIT](LICENSE).

---

**Repository**: https://github.com/AnotherMike-exe/SteamFrameDongleFix · **Maintainer**: Plum Solutions
