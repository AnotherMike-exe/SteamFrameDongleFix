#!/usr/bin/env bats
# Unit tests for bin/steam-frame-dongle. They run on any machine: no dongle,
# no root and no NetworkManager are needed.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CLI="$REPO/bin/steam-frame-dongle"
    # shellcheck source=/dev/null
    source "$CLI"
    DEST="$(mktemp -d)"
}

teardown() {
    rm -rf "$DEST"
}

@test "dm_parse reads the bitmap from the debugfs header line" {
    run dm_parse "Disabled DM: 0x20"
    [ "$status" -eq 0 ]
    [ "$output" = "0x20" ]
}

@test "dm_parse rejects a line without a hex value" {
    run dm_parse "garbage"
    [ "$status" -ne 0 ]
}

@test "dm_set_ips sets bit 5 and keeps the other bits" {
    [ "$(dm_set_ips 0x0)" = "0x20" ]
    [ "$(dm_set_ips 0x5)" = "0x25" ]
    [ "$(dm_set_ips 0x20)" = "0x20" ]
}

@test "dm_clear_ips clears bit 5 and keeps the other bits" {
    [ "$(dm_clear_ips 0x25)" = "0x5" ]
    [ "$(dm_clear_ips 0x20)" = "0x0" ]
    [ "$(dm_clear_ips 0x1)" = "0x1" ]
}

@test "dm_has_ips reports bit 5" {
    dm_has_ips 0x20
    dm_has_ips 0xff
    run dm_has_ips 0x1f
    [ "$status" -ne 0 ]
}

@test "verdict says still needed above the stall threshold" {
    run verdict 9000
    [ "$output" = "still needed" ]
    run verdict 500
    [ "$output" = "not needed on this kernel" ]
}

@test "help exits 0 and lists every command" {
    run "$CLI" help
    [ "$status" -eq 0 ]
    for cmd in status selftest install uninstall replug; do
        [[ "$output" == *"$cmd"* ]]
    done
}

@test "an unknown command exits 2" {
    run "$CLI" frobnicate
    [ "$status" -eq 2 ]
}

@test "version prints the version" {
    run "$CLI" version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^steam-frame-dongle\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "install into DESTDIR puts every file in place" {
    DESTDIR="$DEST" run "$CLI" install
    [ "$status" -eq 0 ]
    [ -x "$DEST/usr/local/bin/steam-frame-dongle" ]
    [ -f "$DEST/etc/NetworkManager/conf.d/90-steam-frame-dongle.conf" ]
    [ -f "$DEST/etc/udev/rules.d/90-steam-frame-dongle.rules" ]
    [ -f "$DEST/etc/systemd/journald.conf.d/90-steam-frame-dongle.conf" ]
    [ -f "$DEST/etc/pacman.d/hooks/90-steam-frame-dongle.hook" ]
}

@test "uninstall from DESTDIR removes every file and is safe to repeat" {
    DESTDIR="$DEST" "$CLI" install
    DESTDIR="$DEST" run "$CLI" uninstall
    [ "$status" -eq 0 ]
    [ -z "$(find "$DEST" -type f)" ]
    DESTDIR="$DEST" run "$CLI" uninstall
    [ "$status" -eq 0 ]
}

@test "the udev rule matches only the Steam Frame adapter and calls the installed CLI" {
    rule="$REPO/Install/Udev/90-steam-frame-dongle.rules"
    grep -q 'ATTRS{idVendor}=="28de"' "$rule"
    grep -q 'ATTRS{idProduct}=="2432"' "$rule"
    grep -q 'RUN+="/usr/bin/systemd-run --no-block --quiet /usr/local/bin/steam-frame-dongle udev-apply \$name"' "$rule"
}

@test "the NetworkManager config turns off MAC randomization for the driver" {
    conf="$REPO/Install/NetworkManager/90-steam-frame-dongle.conf"
    grep -q '^match-device=driver:rtw89_8852cu$' "$conf"
    grep -q '^wifi.scan-rand-mac-address=no$' "$conf"
    grep -q '^wifi.cloned-mac-address=permanent$' "$conf"
}

@test "recover_stale puts back a config that an interrupted selftest renamed" {
    DESTDIR="$DEST" "$CLI" install
    conf="$DEST/etc/NetworkManager/conf.d/90-steam-frame-dongle.conf"
    mv "$conf" "$conf.selftest"
    DESTDIR="$DEST" run recover_stale
    [ "$status" -eq 0 ]
    [ -f "$conf" ]
    [ ! -e "$conf.selftest" ]
}

@test "recover_stale removes a leftover copy when the config exists" {
    DESTDIR="$DEST" "$CLI" install
    conf="$DEST/etc/NetworkManager/conf.d/90-steam-frame-dongle.conf"
    cp "$conf" "$conf.selftest"
    DESTDIR="$DEST" run recover_stale
    [ -f "$conf" ]
    [ ! -e "$conf.selftest" ]
}

@test "uninstall also removes a leftover selftest copy" {
    DESTDIR="$DEST" "$CLI" install
    touch "$DEST/etc/NetworkManager/conf.d/90-steam-frame-dongle.conf.selftest"
    DESTDIR="$DEST" "$CLI" uninstall
    [ -z "$(find "$DEST" -type f)" ]
}

@test "install leaves no temporary files" {
    DESTDIR="$DEST" "$CLI" install
    [ -z "$(find "$DEST" -name '*.new')" ]
}

@test "selftest rejects --profile without a name" {
    DESTDIR="$DEST" run "$CLI" selftest --profile
    [ "$status" -eq 1 ]
    [[ "$output" == *"--profile needs a name"* ]]
}
