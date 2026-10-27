# Quick Reference: SteamFrameDongleFix

> The commands you actually run on this project. Anything that is true of every
> Plum project belongs in the standards, not here.

---

## Daily commands

```bash
# On the gaming PC (root)
sudo ./bin/steam-frame-dongle install     # from the repository
sudo steam-frame-dongle replug            # apply the NetworkManager config now
sudo steam-frame-dongle status
sudo steam-frame-dongle selftest          # about 4 min, causes stalls on purpose
sudo steam-frame-dongle selftest --yes --skip-mac   # about 2 min, no USB reattach
sudo steam-frame-dongle selftest --profile "My Frame"  # another profile name
sudo steam-frame-dongle uninstall

# Logs
journalctl -t steam-frame-dongle -b       # udev applies and selftest results

# Tests and lint (any machine)
bats tests/Unit
shellcheck -x bin/steam-frame-dongle
```

## Installed files

| Repository source | Installed path | Does |
|---|---|---|
| `bin/steam-frame-dongle` | `/usr/local/bin/steam-frame-dongle` | The CLI. udev and pacman call it. |
| `Install/NetworkManager/90-steam-frame-dongle.conf` | `/etc/NetworkManager/conf.d/` | No MAC randomization for driver `rtw89_8852cu` |
| `Install/Udev/90-steam-frame-dongle.rules` | `/etc/udev/rules.d/` | Runs `udev-apply` through `systemd-run` when a `28de:2432` interface appears |
| `Install/Journald/90-steam-frame-dongle.conf` | `/etc/systemd/journald.conf.d/` | `SystemMaxUse=1G` |
| `Install/Pacman/90-steam-frame-dongle.hook` | `/etc/pacman.d/hooks/` | Prints a selftest reminder after a kernel update. Skipped when there is no pacman. |

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `SFD_PROFILE` | `Steam Frame Wireless Adapter` | NetworkManager profile that `selftest` activates. `sudo` removes it, so use `--profile` or `sudo env SFD_PROFILE=...`. |
| `DESTDIR` | empty | Install into or uninstall from another root (packaging and unit tests) |

## Kernel interfaces

| Path | Holds |
|---|---|
| `/sys/kernel/debug/ieee80211/phyN/rtw89/disable_dm` | rtw89 bitmap. Bit 5 (`0x20`) = `INACTIVE_PS` off. Resets on replug and reboot. |
| `/sys/bus/usb/devices/<port>/authorized` | `replug` writes 0 and then 1 |
| `ip link show dev <iface>` | Shows `permaddr` only when the MAC is randomized |

## Troubleshooting

### status shows "MAC address: randomized"
→ NetworkManager reads device settings only when the device appears. Run `sudo steam-frame-dongle replug`.

### status shows "Inactive power save: ON"
→ The udev rule did not run. Check `journalctl -t steam-frame-dongle -b` and `udevadm test /sys/class/net/<iface>`.

### selftest stops with "the activation succeeded"
→ The headset is awake and connected. Put it to sleep and run the test again.

### "could not turn off inactive power save"
→ The message gives the cause. Kernel lockdown (Secure Boot) blocks debugfs writes. Otherwise the kernel is older than 7.2 or has no `CONFIG_RTW89_DEBUGFS`.

### A selftest was interrupted
→ Run `sudo steam-frame-dongle status`. It puts back a renamed config. If the adapter is missing, run `sudo steam-frame-dongle replug` or plug it in again.

## Project links

- [Architecture](ARCHITECTURE.md)
- [Dev setup](DEV-SETUP.md)
- [Issues](https://github.com/AnotherMike-exe/SteamFrameDongleFix/issues)

---

**Scope note for whoever edits this file:** naming rules, Binhex conventions,
documentation layout, and the git workflow are Plum-wide standards and live in the
`plum-standards` skill. Do not restate them here — a copy in every repo is a copy
that goes stale.
