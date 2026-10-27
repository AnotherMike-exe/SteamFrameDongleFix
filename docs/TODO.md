# TODO — SteamFrameDongleFix

Small work that has no issue yet. This file lives at `docs/TODO.md`.

Anything a user would ask for goes to GitHub instead:

- A feature somebody wants → a feature request issue
- A defect → a bug report issue
- A release worth planning → the roadmap

## Now

- [ ] Comment on steam-for-linux #13643 with the root cause and a link to this repository

## Next

- [ ] Find the source of the remaining ~2.7 s stall at the end of each failed activation
- [ ] `selftest`: compare against the baseline, not only the fixed 3000 ms threshold
- [ ] Test on Bazzite and Fedora (no pacman, different NetworkManager defaults)

## Someday

- [ ] AUR package
- [ ] Remove the journald drop-in when the 2.4 GHz patch reaches a released kernel

## Done

- [x] v0.1.0: install, uninstall, status, selftest, replug; tested on CachyOS 7.3.0-4
