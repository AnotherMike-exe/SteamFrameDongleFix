# Architecture — SteamFrameDongleFix

How this project is built and why. `README.md` says what it does. This file says what
somebody must understand before they change it.

## Shape

A single Bash CLI that a user runs by hand as root, plus four config files that it
installs into `/etc`. udev and pacman call the same CLI. There is no daemon and no
container. Every workaround is a separate file, so each one can be removed on its own
when upstream fixes its cause.

## Root cause

Measured on CachyOS, kernel 7.3.0-4, NetworkManager 1.58.1 with wpa_supplicant:

1. Steam asks NetworkManager to activate the hidden-SSID profile "Steam Frame Wireless
   Adapter" every 60 s. When the headset sleeps, the activation fails with
   `ssid-not-found` ([steam-for-linux #13643](https://github.com/ValveSoftware/steam-for-linux/issues/13643)).
2. Each activation scans. With no connection, rtw89 keeps the chip in inactive power
   save (IPS). A scan calls `rtw89_leave_ips` → `rtw89_core_start`, which does about
   10 s of USB control transfers while it holds the wiphy lock.
3. `wpa_supplicant` takes RTNL in `nl80211_pre_doit` and then waits for the wiphy lock.
   Every process that needs RTNL (NetworkManager, Steam, Plasma, many games) blocks.
4. NetworkManager scans with a random MAC. Each MAC change is an interface down/up under
   RTNL, which repeats the 10–15 s chip start, two or three times per retry.
5. Separately, the adapter registers only 5 and 6 GHz but starts on a 2.4 GHz default
   channel. Each received frame hits `WARN_ON(!sband)` in `ieee80211_rx_list`, about
   20 times per second with IPS off.

## Components

| Component | Does | Built with |
|---|---|---|
| `bin/steam-frame-dongle` | install, uninstall, status, selftest, replug, udev-apply, hook-notice | Bash |
| NetworkManager drop-in | Keeps the permanent MAC, which removes cause 4 | NM `conf.d` |
| udev rule | Starts `udev-apply` through `systemd-run` on each add, which sets bit 5 of `disable_dm` and removes cause 2 | udev, systemd-run, debugfs |
| journald drop-in | Raises the journal cap so cause 5 does not wipe other logs | journald |
| pacman hook | Reminds the user to run `selftest` after a kernel update | ALPM hook |

## Data flow

```
USB add -> kernel creates wlanN -> udev rule -> systemd-run steam-frame-dongle udev-apply wlanN
        -> debugfs disable_dm |= 0x20 -> logger (journal tag steam-frame-dongle)

Steam retry -> NetworkManager (permanent MAC, no down/up) -> wpa_supplicant scan
            -> rtw89 hw_scan (chip already on, no 10 s start) -> fails, ~2.7 s stall
```

## Data

| Store | Holds | Lives at | Survives a rebuild |
|---|---|---|---|
| debugfs `disable_dm` | IPS switch | `/sys/kernel/debug/ieee80211/phyN/rtw89/` | No. The udev rule sets it again on each add. |
| journal | udev-apply and selftest results | tag `steam-frame-dongle` | Yes, within the 1 GB cap |

## External dependencies

| Depends on | For | When it is missing |
|---|---|---|
| NetworkManager | MAC setting, selftest activations | The MAC workaround does nothing. `selftest` fails. |
| udev, systemd, journald | IPS rule, journal cap, `logger` | The IPS workaround is not applied at boot |
| Kernel ≥ 7.2 with `CONFIG_RTW89_DEBUGFS` | `disable_dm` | `udev-apply` exits non-zero. `status` shows "unreadable". |
| pacman | Kernel update reminder | `install` skips the hook |
| journald | Warning counts in `status` and `selftest` | Counts show 0 |

## Deployment

Users clone the repository and run `sudo ./bin/steam-frame-dongle install`. Releases are
git tags (`vX.Y.Z`) with GitHub release notes. There is no package yet. Rollback is
`uninstall`, then `install` from the previous tag.

## CI/CD and secrets

| Workflow | Triggers on | Does |
|---|---|---|
| `Review.yml` | pull request, push to `main` | shellcheck, bats unit tests, Claude review on pull requests |

No integration tests run in CI because they need the physical adapter. `selftest` is the
integration test, and it runs on real hardware.

| Secret | Used by | Still to create |
|---|---|---|
| `ANTHROPIC_API_KEY` | `Review.yml` (`claude-review` job) | yes. The job skips itself without it. |

## Security model

- **Trust boundary**: local only. No network listener.
- **Authentication**: none. Every command except `help` and `version` needs root.
- **Runs as**: root, because it writes to `/etc`, debugfs and USB sysfs. udev runs
  `udev-apply` as root with the interface name as the only argument.
- `selftest` changes system state on purpose. INT, TERM and HUP end the script, and the
  EXIT handler then blocks further signals, stops child processes, and sets the final
  state again: config in place, adapter attached, inactive power save off. A config that
  a killed run left renamed (`.selftest`) is restored by the next `status`, `selftest`,
  `install` or `uninstall`.
- On a kernel in lockdown (Secure Boot on some distributions), debugfs writes fail. The
  CLI reports this, and the IPS workaround cannot work there.

## Known limits

- About 2.7 s of stall per Steam retry is left. It comes from the scan and failure path
  itself, and only Valve can remove the retry.
- `selftest` uses a fixed 3000 ms threshold. A kernel that makes the stall 2–3 s without
  a workaround reads as "not needed".
- The NetworkManager drop-in matches every `rtw89_8852cu` adapter, not only `28de:2432`.
  NetworkManager cannot match by USB ID. The only effect on other adapters is no MAC
  randomization during scans.

## Decisions

### Runtime workarounds, not a patched driver

**Chose**: config files and a debugfs switch on the stock kernel driver
**Over**: a DKMS build of rtw89 with the 2.4 GHz and IPS patches
**Because**: CachyOS ships kernels often. A DKMS module can fail to build or hide an upstream fix. Each file here can be removed alone.
**Revisit when**: the 2.4 GHz patch is merged, or a distribution ships a fixed kernel.

### Keep the kernel warnings visible

**Chose**: a larger journal cap
**Over**: filtering kernel messages out of the journal
**Because**: journald cannot filter kernel messages by pattern without losing all of them. Also, when the warnings stop after an update, the user knows the kernel fix has landed.
**Revisit when**: no plan to.

### Manual selftest, not an automatic one

**Chose**: a pacman hook that only prints a reminder
**Over**: an automatic test at boot or after updates
**Because**: the test causes stalls of up to 15 s on purpose, which must not happen during a game.
**Revisit when**: no plan to.

### Not a managed/unmanaged toggle

**Chose**: keep the adapter managed by NetworkManager all the time
**Over**: setting `managed no` until SteamVR starts
**Because**: Steam needs NetworkManager to set up the adapter. The owner rejected a toggle.
**Revisit when**: no plan to.
