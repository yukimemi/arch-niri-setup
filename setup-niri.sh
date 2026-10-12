#!/usr/bin/env bash
# Installed Arch only. Run: sudo bash setup-niri.sh EXISTING_USER
# Sources: https://wiki.archlinux.org/title/Niri
# https://wiki.archlinux.org/title/Greetd
# https://niri-wm.github.io/niri/Configuration:-Introduction.html
# https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl
# No partitions, credentials, passwords, autologin, or automatic reboot are changed.
set -euo pipefail
umask 077
fail() { printf 'setup-niri: %s\n' "$*" >&2; exit 1; }
[[ $# == 1 ]] || fail 'Usage: sudo bash setup-niri.sh EXISTING_NON_ROOT_USER'
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || fail 'An x86_64 Linux system is required.'
[[ $EUID == 0 ]] || fail 'Run this script as root (or through sudo).'
[[ -f /etc/arch-release ]] || fail 'This script requires installed Arch Linux.'
for command in findmnt getent id stat readlink pacman systemctl runuser sha256sum cmp install mktemp cp mv chmod rm; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command is missing: $command"
done
root_type=$(findmnt -n -o FSTYPE -T /) || fail 'Cannot determine the root filesystem.'
case "$root_type" in overlay|aufs|squashfs|tmpfs|ramfs) fail 'Refusing a live/overlay/RAM root. Boot installed Arch or enter its mounted root first.' ;; esac
# Root-local markers also catch live environments using a non-overlay root.
[[ ! -e /etc/archiso && ! -e /etc/initcpio/hooks/archiso ]] || fail 'Arch live ISO detected; refusing package/configuration changes.'
user=$1
[[ $user =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || fail 'Specify an existing local user name, not a UID or an option.'
entry=$(getent passwd "$user") || fail "User does not exist: $user"
IFS=: read -r account _ uid gid _ home shell <<< "$entry"
[[ $account == "$user" && $uid =~ ^[0-9]+$ && $uid -ge 1000 && $uid -ne 65534 ]] || fail 'The target must be an existing regular non-root login user.'
[[ $home == /* && $home != / && -d $home && ! -L $home ]] || fail 'The target needs an existing absolute, non-symlink home directory.'
[[ $(readlink -f -- "$home") == "$home" && $(stat -c %u -- "$home") == "$uid" ]] || fail 'The home path must be canonical and owned by the target user.'
[[ -x $shell && $shell != */nologin && $shell != */false ]] || fail 'The target needs a usable login shell.'
# Do not silently replace an existing graphical login setup, including disabled ones.
for package in gdm sddm lightdm lxdm slim ly cosmic-greeter; do
    if pacman -Q "$package" >/dev/null 2>&1; then
        fail "Existing display-manager package $package detected. Resolve that setup explicitly before running this script."
    fi
done
if [[ -e /etc/systemd/system/display-manager.service || -L /etc/systemd/system/display-manager.service ]]; then
    [[ $(readlink -f /etc/systemd/system/display-manager.service) == */greetd.service ]] || fail 'An unexpected display-manager.service is already configured.'
fi
# In an arch-chroot, inspect/enable the installed root; never control the live host.
in_chroot=false
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --chroot --quiet; then in_chroot=true; fi
for service in gdm sddm lightdm lxdm slim ly xdm; do
    if systemctl --root=/ is-enabled "$service.service" >/dev/null 2>&1; then
        fail "Unexpected enabled display manager: $service"
    fi
    if ! "$in_chroot" && systemctl is-active --quiet "$service.service"; then
        fail "Unexpected running display manager: $service"
    fi
done
bundle=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
expected=d5c6f92cabc231b4fb94c47322fc67b3c473c3b107339237a4b2f16505b38342
matches_binary() {
    local digest
    digest=$(sha256sum < "$1") || return 1
    [[ ${digest%% *} == "$expected" ]]
}
[[ -r $bundle/omp-linux-x64 && -f $bundle/omp-linux-x64 && -r $bundle/HANDOFF.md && -f $bundle/HANDOFF.md ]] || fail 'Keep omp-linux-x64 and HANDOFF.md beside this script.'
matches_binary "$bundle/omp-linux-x64" || fail 'Bundled OMP does not match pinned v18.10.0 checksum.'
workspace="$home/arch-handoff"
config="$home/.config/niri/config.kdl"
# All writes inside HOME run as the user, never as root.
as_user() { runuser -u "$user" -- env HOME="$home" USER="$user" LOGNAME="$user" XDG_CONFIG_HOME="$home/.config" "$@"; }
for directory in "$home/.config" "$home/.config/niri" "$workspace" "$workspace/bin"; do
    if [[ -e $directory || -L $directory ]]; then
        [[ -d $directory && ! -L $directory && $(stat -c %u -- "$directory") == "$uid" ]] || fail "Unsafe existing user directory: $directory"
        if [[ $directory == "$workspace" || $directory == "$workspace/bin" ]]; then
            [[ $(stat -c %a -- "$directory") == 700 ]] || fail "Workspace directories must already have mode 700: $directory"
        fi
    fi
done
for file in "$config" "$workspace/bin/omp" "$workspace/HANDOFF.md"; do
    if [[ -e $file || -L $file ]]; then
        [[ -f $file && ! -L $file && $(stat -c %u -- "$file") == "$uid" ]] || fail "Unsafe existing user file: $file"
    fi
done
if [[ -e $workspace/bin/omp ]]; then
    matches_binary "$workspace/bin/omp" || fail 'Refusing to replace a different existing workspace OMP binary.'
fi
[[ ! -L /etc/greetd && ! -L /etc/greetd/config.toml ]] || fail 'Refusing symlinked greetd configuration.'
if [[ -e /etc/greetd/config.toml ]]; then
    [[ -f /etc/greetd/config.toml && $(stat -c %u /etc/greetd/config.toml) == 0 ]] || fail 'greetd config must be a root-owned regular file.'
fi
# Include per-interface dhcpcd and netctl profiles, not just singleton services.
networkmanager_enable=true
network_units=$(systemctl --root=/ list-unit-files --state=enabled,enabled-runtime --no-legend --no-pager \
    'systemd-networkd.service' 'connman.service' 'dhcpcd*.service' 'netctl*.service') \
    || fail 'Cannot inspect existing network manager units.'
while read -r service rest; do
    case "$service" in
        systemd-networkd.service|connman.service|dhcpcd*.service|netctl*.service)
            networkmanager_enable=false
            printf 'Preserving existing network manager: %s\n' "$service"
            ;;
    esac
done <<< "$network_units"
stage=$(mktemp -d /tmp/setup-niri.XXXXXXXX)
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Non-secret, root-owned staging is readable by the target even from /root bundles.
chmod 755 "$stage"
install -m 644 -- "$bundle/omp-linux-x64" "$stage/omp"
install -m 644 -- "$bundle/HANDOFF.md" "$stage/HANDOFF.md"
matches_binary "$stage/omp" || fail 'Staged OMP checksum mismatch.'
cat > "$stage/config.kdl" <<'KDL'
// Minimal installed-Arch setup; Super is Mod on the physical login session.
// Japanese physical keymap, not a Japanese input-method engine.
input {
    keyboard { xkb { layout "jp"; }; }
    touchpad { tap; natural-scroll; }
}
layout {
    gaps 8
    default-column-width { proportion 0.5; }
    focus-ring { width 2; active-color "#7fc8ff"; }
}
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
binds {
    Mod+T hotkey-overlay-title="Terminal" { spawn "alacritty"; }
    Mod+D hotkey-overlay-title="Launcher" { spawn "fuzzel"; }
    Mod+B hotkey-overlay-title="Firefox" { spawn "firefox"; }
    Mod+Shift+E hotkey-overlay-title="Log out (confirmation)" { quit; }
    Mod+Q { close-window; }
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up { focus-window-up; }
    Mod+Down { focus-window-down; }
    Mod+Shift+Left { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Up { move-window-up; }
    Mod+Shift+Down { move-window-down; }
    Mod+Page_Up { focus-workspace-up; }
    Mod+Page_Down { focus-workspace-down; }
    Mod+Ctrl+Page_Up { move-column-to-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+R { switch-preset-column-width; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    Mod+Shift+Slash { show-hotkey-overlay; }
}
KDL
cat > "$stage/greetd.toml" <<'TOML'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --cmd /usr/bin/niri-session"
user = "greeter"
TOML
chmod 644 "$stage/config.kdl" "$stage/greetd.toml"
consent() {
    local answer
    printf '\n%s\nType yes to replace it with a backed-up copy; anything else aborts: ' "$1" >&2
    if ! read -r answer </dev/tty; then fail 'Replacement requires an interactive terminal and explicit consent.'; fi
    [[ $answer == yes ]] || fail 'Replacement declined; existing configuration is unchanged.'
}
# Ask before the package transaction for all already-existing differing files.
if [[ -e $config ]] && ! cmp -s "$stage/config.kdl" "$config"; then consent "Existing niri configuration differs: $config"; fi
if [[ -e $workspace/HANDOFF.md ]] && ! cmp -s "$stage/HANDOFF.md" "$workspace/HANDOFF.md"; then consent "Existing handoff notes differ: $workspace/HANDOFF.md"; fi
greetd_approved=false
if [[ -e /etc/greetd/config.toml ]] && ! cmp -s "$stage/greetd.toml" /etc/greetd/config.toml; then
    consent 'Existing /etc/greetd/config.toml differs.'
    greetd_approved=true
fi
printf '\nUpdating all Arch packages and installing niri + Firefox. Review pacman prompts.\n'
desktop_packages=(niri firefox alacritty fuzzel waybar mako
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk polkit-gnome
    xwayland-satellite xdg-utils noto-fonts noto-fonts-cjk ttf-dejavu
    greetd greetd-tuigreet)
if "$networkmanager_enable"; then desktop_packages+=(networkmanager); fi
pacman -Syu --needed "${desktop_packages[@]}"
for command in niri niri-session tuigreet firefox alacritty; do
    command -v "$command" >/dev/null 2>&1 || fail "Installed command is missing: $command"
done
[[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]] || fail 'Installed polkit agent is missing.'
getent passwd greeter >/dev/null || fail 'greetd package did not provide the greeter account.'
# Real installed niri validates the candidate as the normal user, before publishing.
as_user niri validate --config "$stage/config.kdl"
if [[ -e /etc/greetd/config.toml ]] && ! cmp -s "$stage/greetd.toml" /etc/greetd/config.toml && ! "$greetd_approved"; then
    consent 'The greetd package supplied a differing /etc/greetd/config.toml.'
fi
as_user mkdir -p -m 700 -- "$home/.config/niri" "$workspace/bin"
backup_user_file() {
    local backup
    backup=$(as_user mktemp "$1.backup.XXXXXXXX")
    as_user cp -p -- "$1" "$backup"
    printf 'Preserved backup: %s\n' "$backup"
}
install_user_file() {
    local source=$1 destination=$2 mode=$3 temporary
    if [[ -e $destination ]] && cmp -s "$source" "$destination"; then
        as_user chmod "$mode" "$destination"
        return
    fi
    if [[ -e $destination ]]; then backup_user_file "$destination"; fi
    temporary=$(as_user mktemp "$destination.new.XXXXXXXX")
    as_user install -m "$mode" -- "$source" "$temporary"
    as_user mv -f -- "$temporary" "$destination"
}
install_user_file "$stage/config.kdl" "$config" 600
install_user_file "$stage/omp" "$workspace/bin/omp" 700
install_user_file "$stage/HANDOFF.md" "$workspace/HANDOFF.md" 600
matches_binary "$workspace/bin/omp" || fail 'Installed OMP checksum mismatch.'
as_user niri validate --config "$config"
as_user "$workspace/bin/omp" --version
if ! cmp -s "$stage/greetd.toml" /etc/greetd/config.toml; then
    if [[ -e /etc/greetd/config.toml ]]; then
        backup=$(mktemp /etc/greetd/config.toml.backup.XXXXXXXX)
        cp -p -- /etc/greetd/config.toml "$backup"
        printf 'Preserved backup: %s\n' "$backup"
    fi
    install -d -m 755 /etc/greetd
    install -m 644 "$stage/greetd.toml" /etc/greetd/config.toml
fi
# Enable only: do not seize the current VT, disrupt the current network, or reboot.
systemctl --root=/ enable greetd.service
if "$networkmanager_enable"; then systemctl --root=/ enable NetworkManager.service; fi
systemctl --root=/ set-default graphical.target
printf '\nSetup complete. No compositor/login manager was started and no reboot occurred.\n'
printf 'At your next normal installed-Arch boot, log into tuigreet on tty1 as %s with your existing password.\n' "$user"
printf 'If already logged into a normal-user text console, start: niri-session -l\n'
printf 'If greetd was already running, its new configuration takes effect at its next restart/boot; this script did not restart it.\n'
printf 'Fallback: Ctrl+Alt+F2 opens tty2; log in there as %s and run niri-session -l if no graphical session is active.\n' "$user"
printf 'Inside niri: Super+T = terminal, Super+D = launcher, Super+B = Firefox, Super+Shift+E = logout.\n'
printf 'Super+arrows navigates windows; Super+PageUp/PageDown changes workspaces.\n'
printf 'In that NORMAL-USER terminal (not sudo/root), run exactly:\n'
printf '  cd %q\n  ./bin/omp login openai-codex\n' "$workspace"
printf 'Firefox should open the browser OAuth page; finish it and return to the terminal.\n'
printf 'If it does not open, press Super+B and paste the URL printed by OMP; keep OMP running for the localhost callback.\n'
printf 'Then start the handoff conversation:\n  ./bin/omp --cwd . @HANDOFF.md\n'
printf 'No credentials were imported/exported. Login requires working internet and your own permitted account.\n'
if "$networkmanager_enable"; then
    printf 'NetworkManager starts at next boot; configure Wi-Fi with nmtui as needed. Existing connection was not changed.\n'
else
    printf 'Existing enabled network manager preserved; NetworkManager was not enabled.\n'
fi
printf 'Japanese glyphs and jp physical keymap are installed; Japanese text composition/IME is not included.\n'
