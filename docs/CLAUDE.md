# CLAUDE.md — SteamFrameDongleFix

Project memory for Claude Code. Keep it true: a line that is wrong is worse than a line
that is missing, because it is trusted.

## What this is

A root CLI plus four config files that stop the 10–17 s system-wide stalls that the
Valve Steam Frame wireless adapter (USB `28de:2432`, RTL8852CU, `rtw89_8852cu`) causes
on Linux with NetworkManager. Gamers on CachyOS, Arch and similar distributions install
it from a clone. `selftest` tells them when a kernel update makes a workaround
unnecessary, so the project removes itself when upstream fixes the cause.

**Stage**: beta (v0.1.0, tested on one CachyOS PC)
**Deployed on**: the owner's gaming PC, PlumGaming (CachyOS, kernel 7.3.0-4)

## Stack

| Part | Choice |
|---|---|
| Language | Bash (functions must also run on Bash 3.2, for unit tests on macOS) |
| Tests | bats-core, shellcheck |
| Installs into | NetworkManager `conf.d`, udev `rules.d`, journald `conf.d`, pacman hooks |
| Kernel interface | debugfs `ieee80211/phyN/rtw89/disable_dm`, USB sysfs `authorized` |

## Layout

```
bin/steam-frame-dongle   the CLI; udev and pacman call the installed copy
Install/                 config files, one subdirectory per target system
tests/Unit/              bats tests; run anywhere, no root, no adapter
docs/                    every document except README.md
_resources/              dev references, never in git (notes, probe, test CSVs)
```

## Commands

```bash
bats tests/Unit                                  # test
shellcheck -x bin/steam-frame-dongle             # lint
sudo ./bin/steam-frame-dongle install            # on the PC, from the repository
sudo steam-frame-dongle status
sudo steam-frame-dongle selftest --yes           # integration test on real hardware
```

If the test PC uses fish as its login shell, wrap remote commands in
`bash -c '...'` or `ssh ... 'bash -s' <<'EOF'`.

## Conventions

**Naming**: the executable and the installed config files are lowercase with dashes
(`steam-frame-dongle`, `90-steam-frame-dongle.conf`), because that is the convention for
`/usr/local/bin`, `conf.d` and `rules.d`. Bash functions are `snake_case`, the Bash
idiom. Repository directories and documentation filenames are PascalCase. Constants are
`UPPER_SNAKE_CASE`.

**Errors**: `die` prints to stderr and exits 1. A bad command exits 2. `measure_cycle`
returns 3 when the activation succeeds (headset awake). The script uses
`set -uo pipefail` without `-e`, so check each command that can fail.

**Project-specific rules**:
- Every installed file is in `install_map`. `install`, `uninstall` and `status` all read
  that list. Add a new file there, never in one command only.
- A function that the unit tests call must not touch the system. Keep the sysfs and
  `nmcli` calls in the `cmd_*` and discovery functions.
- `selftest` turns workarounds off on purpose. Any new step needs a restore path in
  `selftest_restore`, which the trap calls.

## How to work here

**Plan mode** for anything beyond a single-file edit: a refactor, anything touching CI,
or any change to what `install` writes. Show the plan and wait for a yes.

**A subagent** for work that parallelizes — a research spike, reading a long reference,
an independent audit. The main thread integrates the result.

**Ask early.** An architecture question answered before the work costs a minute. The
same question answered after costs the work.

Standing rules for this repo: rebase, never merge. `_resources/` never enters git. CI
green before merge.

## The phase loop

Each phase of the build runs the same five steps.

1. `/resume-session` — restore the state the last phase left
2. Build. Name `tdd-workflow` only for a bug fix, where the test is the reproducer
3. `verification-loop` — the gate at the end of the phase
4. Review in parallel: `code-reviewer`, `security-reviewer` and `code-reviewer` with a
   shell focus (there is no dedicated Bash reviewer)
5. `/learn-eval`, then `/save-session`

Commit at the end of every phase. A local commit costs nothing and gives the review a
diff to read.

`blueprint` holds the phase plan between sessions. Each step in it carries a brief that a
fresh session can execute cold.

## Gotchas

- `status` shows "MAC address: randomized" after install → NetworkManager reads device
  settings only when the device appears; `nmcli general reload conf` is not enough →
  run `replug`.
- The phy number changes on every replug (`phy2`, `phy3`, ...) → never hard-code it;
  use `phy_of`.
- `selftest` output had bash `Done` job lines → background jobs inside `measure_cycle`
  print notices on stderr → callers redirect `measure_cycle 2>/dev/null`.
- A variable set inside `$(...)` is lost → `measure_cycle` prints all its results on
  one line, and the caller uses `read`.
- `sampler: unbound variable` at exit → an EXIT trap runs after the function's locals
  are gone, and `set -u` fails → trap state lives in globals (`MC_*`).
- A test that starts `selftest &` and sends SIGINT does nothing → bash ignores SIGINT in
  background jobs → test with `setsid` and `kill -TERM -- -<pgid>`.
- `pkill -f "steam-frame-dongle selftest"` also hits the script's own subshells, which
  share the command line → signal the process group instead.

## Where the rules live

The Plum Solutions standards — naming, Binhex Docker layout, documentation rules, git
workflow — are in the `plum-standards` skill, not copied here. A copy in every repo is a
copy that goes stale.

This file holds only what is true of **this** project.
