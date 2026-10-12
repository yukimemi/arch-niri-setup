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
for command in findmnt getent id stat readlink pacman systemctl runuser curl sha256sum grep install mktemp cp mv chmod rm; do
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
[[ -r $bundle/HANDOFF.md && -f $bundle/HANDOFF.md ]] || fail 'Keep HANDOFF.md beside this script.'
workspace="$home/arch-handoff"
config="$home/.config/niri/config.kdl"
fcitx_config="$home/.config/fcitx5/config"
fcitx_profile="$home/.config/fcitx5/profile"
chromium_flags="$home/.config/chromium-flags.conf"
login_profile=''
case "${shell##*/}" in
    bash) login_profile="$home/.bash_profile" ;;
    zsh) login_profile="$home/.zprofile" ;;
esac
omp_path='export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"'
# All writes inside HOME run as the user, never as root.
as_user() { runuser -u "$user" -- env HOME="$home" USER="$user" LOGNAME="$user" XDG_CONFIG_HOME="$home/.config" PATH="$home/.local/bin:$home/.bun/bin:$PATH" "$@"; }
for directory in "$home/.config" "$home/.config/niri" "$home/.config/fcitx5" "$home/.local" "$home/.local/bin" "$workspace"; do
    if [[ -e $directory || -L $directory ]]; then
        [[ -d $directory && ! -L $directory && $(stat -c %u -- "$directory") == "$uid" ]] || fail "Unsafe existing user directory: $directory"
        if [[ $directory == "$workspace" ]]; then
            [[ $(stat -c %a -- "$directory") == 700 ]] || fail "Workspace directory must already have mode 700: $directory"
        fi
    fi
done
for file in "$config" "$fcitx_config" "$fcitx_profile" "$chromium_flags" "$workspace/HANDOFF.md" "$login_profile"; do
    if [[ -e $file || -L $file ]]; then
        [[ -f $file && ! -L $file && $(stat -c %u -- "$file") == "$uid" ]] || fail "Unsafe existing user file: $file"
    fi
done
profile_add=false
if [[ -n $login_profile ]] && ! as_user grep -Fxq -- "$omp_path" "$login_profile" 2>/dev/null; then profile_add=true; fi
yay_install=true
if as_user sh -c 'command -v yay >/dev/null 2>&1'; then
    yay_install=false
    printf 'Preserving existing yay installation.\n'
else
    [[ -r $bundle/yay.PKGBUILD && -f $bundle/yay.PKGBUILD ]] || fail 'Keep the reviewed yay.PKGBUILD beside this script.'
fi
[[ ! -L /etc/greetd && ! -L /etc/greetd/config.toml ]] || fail 'Refusing symlinked greetd configuration.'
if [[ -e /etc/greetd/config.toml ]]; then
    [[ -f /etc/greetd/config.toml && $(stat -c %u /etc/greetd/config.toml) == 0 ]] || fail 'greetd config must be a root-owned regular file.'
fi
# Include per-interface dhcpcd and netctl profiles, not just singleton services.
networkmanager_enable=true
# Filter in Bash: systemctl returns 1 when supplied patterns match no units.
network_units=$(systemctl --root=/ list-unit-files --state=enabled,enabled-runtime --no-legend --no-pager) \
    || fail 'Cannot inspect existing network manager units.'
while read -r service rest; do
    case "$service" in
        systemd-networkd.service|connman.service|dhcpcd*.service|netctl*.service)
            networkmanager_enable=false
            printf 'Preserving existing network manager: %s\n' "$service"
            ;;
    esac
done <<< "$network_units"
# cmp is in diffutils, which minimal Arch base does not include.
if ! command -v cmp >/dev/null 2>&1; then
    pacman -Syu --needed diffutils
fi
stage=$(mktemp -d /tmp/setup-niri.XXXXXXXX)
profile_stage=''
trap 'if [[ -n $profile_stage ]]; then as_user rm -f -- "$profile_stage"; fi; rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Non-secret, root-owned staging is readable by the target even from /root bundles.
chmod 755 "$stage"
install -m 644 -- "$bundle/HANDOFF.md" "$stage/HANDOFF.md"
if "$yay_install"; then install -m 644 -- "$bundle/yay.PKGBUILD" "$stage/yay.PKGBUILD"; fi
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
environment {
    XMODIFIERS "@im=fcitx"
    QT_IM_MODULE "fcitx"
}
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
binds {
    Mod+T hotkey-overlay-title="Terminal" { spawn "alacritty"; }
    Mod+D hotkey-overlay-title="Launcher" { spawn "fuzzel"; }
    Mod+B hotkey-overlay-title="Chromium" { spawn "chromium"; }
    Mod+Space hotkey-overlay-title="Japanese input on/off" { spawn "fcitx5-remote" "-t"; }
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
cat > "$stage/fcitx5-config" <<'INI'
[Hotkey]
ConsumeRedundantActivateKeys=True

[Hotkey/ActivateKeys]
0=Henkan

[Hotkey/DeactivateKeys]
0=Muhenkan
INI
cat > "$stage/fcitx5-profile" <<'INI'
[Groups/0]
Name=Default
Default Layout=jp
DefaultIM=mozc

[Groups/0/Items/0]
Name=keyboard-jp
Layout=

[Groups/0/Items/1]
Name=mozc
Layout=

[GroupOrder]
0=Default
INI
cat > "$stage/chromium-flags.conf" <<'FLAGS'
--enable-wayland-ime
--wayland-text-input-version=3
FLAGS
cat > "$stage/greetd.toml" <<'TOML'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --cmd /usr/bin/niri-session"
user = "greeter"
TOML
chmod 644 "$stage/config.kdl" "$stage/greetd.toml" "$stage/fcitx5-config" "$stage/fcitx5-profile" "$stage/chromium-flags.conf"
consent() {
    local answer
    printf '\n%s\nType yes to replace it with a backed-up copy; anything else aborts: ' "$1" >&2
    if ! read -r answer </dev/tty; then fail 'Replacement requires an interactive terminal and explicit consent.'; fi
    [[ $answer == yes ]] || fail 'Replacement declined; existing configuration is unchanged.'
}
# Ask before the package transaction for all already-existing differing files.
if [[ -e $config ]] && ! cmp -s "$stage/config.kdl" "$config"; then consent "Existing niri configuration differs: $config"; fi
if [[ -e $workspace/HANDOFF.md ]] && ! cmp -s "$stage/HANDOFF.md" "$workspace/HANDOFF.md"; then consent "Existing handoff notes differ: $workspace/HANDOFF.md"; fi
if [[ -e $fcitx_config ]] && ! cmp -s "$stage/fcitx5-config" "$fcitx_config"; then consent "Existing Fcitx5 hotkeys differ: $fcitx_config"; fi
if [[ -e $fcitx_profile ]] && ! cmp -s "$stage/fcitx5-profile" "$fcitx_profile"; then consent "Existing Fcitx5 input methods differ: $fcitx_profile"; fi
if [[ -e $chromium_flags ]] && ! cmp -s "$stage/chromium-flags.conf" "$chromium_flags"; then consent "Existing Chromium flags differ: $chromium_flags"; fi
if "$profile_add" && [[ -e $login_profile ]]; then consent "Adding OMP to the login-shell PATH in: $login_profile"; fi
greetd_approved=false
if [[ -e /etc/greetd/config.toml ]] && ! cmp -s "$stage/greetd.toml" /etc/greetd/config.toml; then
    consent 'Existing /etc/greetd/config.toml differs.'
    greetd_approved=true
fi
printf '\nUpdating all Arch packages and installing niri + Chromium. Review pacman prompts.\n'
desktop_packages=(niri chromium alacritty fuzzel waybar mako
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk polkit-gnome
    xwayland-satellite xdg-utils noto-fonts noto-fonts-cjk ttf-dejavu
    greetd greetd-tuigreet github-cli git sudo
    fcitx5 fcitx5-mozc fcitx5-configtool fcitx5-gtk fcitx5-qt)
if "$networkmanager_enable"; then desktop_packages+=(networkmanager); fi
if "$yay_install"; then desktop_packages+=(base-devel go); fi
pacman -Syu --needed "${desktop_packages[@]}"
for command in niri niri-session tuigreet chromium alacritty fcitx5 fcitx5-remote fcitx5-configtool gh; do
    command -v "$command" >/dev/null 2>&1 || fail "Installed command is missing: $command"
done
[[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]] || fail 'Installed polkit agent is missing.'
getent passwd greeter >/dev/null || fail 'greetd package did not provide the greeter account.'
# Real installed niri validates the candidate as the normal user, before publishing.
as_user niri validate --config "$stage/config.kdl"
if "$yay_install"; then
    printf '\nBuilding the reviewed, SHA256-pinned yay source as %s, not root.\n' "$user"
    install -d -o "$uid" -g "$gid" -m 700 -- "$stage/yay-build"
    as_user install -m 600 -- "$stage/yay.PKGBUILD" "$stage/yay-build/PKGBUILD"
    as_user env PKGDEST="$stage/yay-build" SRCDEST="$stage/yay-build" \
        bash -c 'cd -- "$1"; makepkg --cleanbuild --nosign --config /etc/makepkg.conf' bash "$stage/yay-build"
    yay_package=("$stage/yay-build"/yay-[0-9]*-x86_64.pkg.tar.*)
    [[ ${#yay_package[@]} == 1 && -f ${yay_package[0]} && ! -L ${yay_package[0]} ]] || fail 'Expected one built yay package archive.'
    pacman -U --needed "${yay_package[@]}"
fi
as_user yay --version
if [[ -e /etc/greetd/config.toml ]] && ! cmp -s "$stage/greetd.toml" /etc/greetd/config.toml && ! "$greetd_approved"; then
    consent 'The greetd package supplied a differing /etc/greetd/config.toml.'
fi
as_user mkdir -p -m 700 -- "$home/.config" "$home/.config/niri" "$home/.config/fcitx5" "$home/.local" "$home/.local/bin" "$workspace"
printf '\nInstalling latest OMP through https://omp.sh/install as %s, not root.\n' "$user"
curl -fsSL https://omp.sh/install -o "$stage/omp-install.sh"
chmod 644 "$stage/omp-install.sh"
as_user sh "$stage/omp-install.sh"
as_user omp --version
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
install_user_file "$stage/fcitx5-config" "$fcitx_config" 600
install_user_file "$stage/fcitx5-profile" "$fcitx_profile" 600
install_user_file "$stage/chromium-flags.conf" "$chromium_flags" 600
install_user_file "$stage/HANDOFF.md" "$workspace/HANDOFF.md" 600
if "$profile_add"; then
    profile_stage=$(as_user mktemp "$home/.omp-profile.XXXXXXXX")
    if [[ -e $login_profile ]]; then as_user cp -p -- "$login_profile" "$profile_stage"; fi
    as_user sh -c 'printf "\n%s\n" "$2" >> "$1"' sh "$profile_stage" "$omp_path"
    install_user_file "$profile_stage" "$login_profile" 600
    as_user rm -- "$profile_stage"
    profile_stage=''
fi
as_user niri validate --config "$config"
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
printf 'Inside niri: Super+T = terminal, Super+D = launcher, Super+B = Chromium, Super+Shift+E = logout.\n'
printf 'Super+arrows navigates windows; Super+PageUp/PageDown changes workspaces.\n'
printf 'In that NORMAL-USER terminal (not sudo/root), run exactly:\n'
printf '  export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"\n'
printf '  cd %q\n  omp login openai-codex\n' "$workspace"
printf 'Chromium should open the browser OAuth page; finish it and return to the terminal.\n'
printf 'If it does not open, press Super+B and paste the URL printed by OMP; keep OMP running for the localhost callback.\n'
printf 'Then start the handoff conversation:\n  omp --cwd . @HANDOFF.md\n'
printf 'No credentials were imported/exported. Login requires working internet and your own permitted account.\n'
if "$networkmanager_enable"; then
    printf 'NetworkManager starts at next boot; configure Wi-Fi with nmtui as needed. Existing connection was not changed.\n'
else
    printf 'Existing enabled network manager preserved; NetworkManager was not enabled.\n'
fi
printf 'Japanese IME: Fcitx5 + Mozc starts through packaged XDG autostart in the niri session.\n'
printf 'Muhenkan = IME off, Henkan = IME on, Super+Space = toggle. Type nihongo, Space, then Enter to convert.\n'
printf 'Existing apps keep their old environment. Save work and reopen Chromium to apply its Wayland IME flags.\n'
printf 'GitHub CLI is installed. Authenticate as the NORMAL USER with: gh auth login\n'
printf 'yay is available for AUR packages. Run it as the NORMAL USER; review PKGBUILDs before installing.\n'
printf 'OMP uses the official installer defaults (existing compatible Bun or verified prebuilt binary); no release is pinned.\n'
if [[ -n $login_profile ]]; then
    printf 'OMP PATH is configured in %s. New login sessions will use it; export PATH above in an existing terminal.\n' "$login_profile"
else
    printf 'Add the PATH export above to your login-shell configuration if omp is not found in future sessions.\n'
fi
