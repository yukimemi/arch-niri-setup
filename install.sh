#!/usr/bin/env bash
# Fetch a pinned, credential-free bundle and configure an already installed Arch.
set -euo pipefail
umask 077
fail() { printf 'arch-niri-setup: %s\n' "$*" >&2; exit 1; }
[[ $# == 1 ]] || fail 'Usage: sudo bash install.sh EXISTING_NON_ROOT_USER'
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || fail 'x86_64 Linux is required.'
[[ $EUID == 0 ]] || fail 'Run through sudo, specifying your existing normal user.'
[[ -f /etc/arch-release ]] || fail 'Installed Arch Linux is required.'
root_type=$(findmnt -n -o FSTYPE -T /)
case "$root_type" in overlay|aufs|squashfs|tmpfs|ramfs) fail 'Do not run this desktop installer in the live ISO. Install and boot Arch first.' ;; esac
[[ ! -e /etc/archiso && ! -e /etc/initcpio/hooks/archiso ]] || fail 'Arch live ISO detected.'
user=$1
[[ $user =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || fail 'Invalid existing user name.'
uid=$(id -u "$user") || fail 'Create a normal user before running setup.'
[[ $uid -ge 1000 && $uid -ne 65534 ]] || fail 'The target must be a normal user, not root.'

# Arch does not support partial upgrades: update the system when adding dependencies.
pacman -Syu --needed curl jq diffutils
bundle=$(mktemp -d /tmp/arch-niri-setup.XXXXXXXX)
trap 'rm -rf -- "$bundle"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
base=https://raw.githubusercontent.com/yukimemi/arch-niri-setup/v1.0.2
curl -fsSL "$base/setup-niri.sh" -o "$bundle/setup-niri.sh"
curl -fsSL "$base/HANDOFF.md" -o "$bundle/HANDOFF.md"
expected=d5c6f92cabc231b4fb94c47322fc67b3c473c3b107339237a4b2f16505b38342
metadata=$(curl -fsSL 'https://build.stencil.so/api/products/omp/versions/18.10.0/linux-x86_64')
url=$(jq -er --arg expected "$expected" 'select(.build.version == "18.10.0" and .file.name == "omp-linux-x64" and .file.sha256 == $expected) | .download | select(startswith("https://"))' <<< "$metadata") || fail 'Unexpected official OMP build metadata.'
curl -fsSL "$url" -o "$bundle/omp-linux-x64"
digest=$(sha256sum < "$bundle/omp-linux-x64")
[[ ${digest%% *} == "$expected" ]] || fail 'OMP SHA256 mismatch; desktop setup was not run.'
bash "$bundle/setup-niri.sh" "$user"
