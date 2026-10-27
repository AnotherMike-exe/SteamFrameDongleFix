# Dev Setup — SteamFrameDongleFix

From a fresh clone to a running, tested copy. If a step here fails, the project is
wrong, not the reader.

Target: 10 minutes. The unit tests run on any machine. The selftest needs a Linux PC
with the Steam Frame adapter plugged in.

## Prerequisites

| Tool | Version | Check |
|---|---|---|
| Bash | 3.2 or newer (unit tests), 4 or newer (on the PC) | `bash --version` |
| bats-core | any | `bats --version` |
| shellcheck | any | `shellcheck --version` |
| git | any | `git --version` |

On the gaming PC: Linux 7.2 or newer with `CONFIG_RTW89_DEBUGFS=y`, NetworkManager,
systemd, udev, util-linux. Pair the headset in Steam one time, so that Steam creates the
"Steam Frame Wireless Adapter" profile.

## 1. Clone

```bash
git clone https://github.com/AnotherMike-exe/SteamFrameDongleFix.git
cd SteamFrameDongleFix
git config pull.rebase true
```

`pull.rebase` keeps history linear, which the ruleset on `main` enforces anyway.

## 2. Install

Nothing to install for development. Create `_resources/` if you keep working notes. It
is in `.gitignore` and never reaches the repository:

```bash
mkdir -p _resources/{Examples,Research,Assets,Notes}
```

## 3. Run

On the gaming PC:

```bash
sudo ./bin/steam-frame-dongle install
sudo steam-frame-dongle replug
sudo steam-frame-dongle status
```

Working when `status` shows `MAC address: permanent` and
`Inactive power save: off (disable_dm 0x20)`.

## 4. Test

```bash
bats tests/Unit                          # any machine, no root
shellcheck -x bin/steam-frame-dongle
sudo steam-frame-dongle selftest         # on the PC, headset asleep, about 4 min
```

CI runs the first two. Run `selftest` by hand before a release that changes
`measure_cycle`, `replug` or the install map.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|

Add a row the first time somebody hits a problem.

## Where the rest is

| Question | Document |
|---|---|
| How it is built and why | `docs/ARCHITECTURE.md` |
| How Claude should work here | `docs/CLAUDE.md` |
| Commands, ports and paths at a glance | `docs/QUICK-REFERENCE.md` |
| What it does, for a user | `README.md` |
