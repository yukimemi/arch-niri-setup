# Changelog

## v1.3.0

- Replace the default Waybar, mako, fuzzel and polkit-gnome startup with maintained native Noctalia from Arch extra; retain existing packages and running sessions.
- Configure Japanese Noctalia UI, native notifications and polkit, and UPower for laptop battery integration.
- Add launcher, control-center and settings bindings; keep the existing Japanese IME controls.
- Route brightness keys through Noctalia's current-monitor selection with 10% steps and a 5% minimum, without machine-specific device names.
- Bind niri region/screen/window screenshots, create a private screenshot directory, and expire screenshot notifications after five seconds.
- Leave clipboard history disabled while preserving normal copy/paste; retain Noctalia GUI overrides and unrelated autostart/services.
- Apply ownership/symlink checks, explicit replacement consent and backups to the managed Noctalia configuration.

## v1.2.0

- Install Fcitx5 + Mozc and GTK/Qt input modules; configure Japanese input, packaged XDG autostart and Chromium Wayland text-input-v3.
- Bind Muhenkan to IME off and Henkan to IME on, including repeated-key idempotence; retain Super+Space as a toggle.
- Protect the new user configuration paths with ownership/symlink checks, explicit replacement consent and backups.
- Install GitHub CLI and git. Preserve existing yay or build reviewed, SHA256-pinned yay 13.0.1 as the normal user.
- Use the official OMP installer as the normal user for the latest release; preserve existing Bash/Zsh profile contents while adding its PATH with consent and backup.
- Remove the bundled OMP version/checksum, independent binary download and obsolete offline bootstrap; migrate authentication and handoff commands to `omp`.

## v1.1.1

- Create the workspace parent explicitly with mode 700; mkdir's mode option does not apply to implicitly created parents.

## v1.1.0

- Use Chromium from the official Arch repository for the requested niri desktop.
- Update the browser key binding and same-machine OAuth instructions; retain the browser sandbox.

## v1.0.2

- Handle fresh Arch systems with no enabled network manager: enumerate all enabled units before filtering network services.

## v1.0.1

- Install diffutils explicitly: minimal Arch base does not provide cmp.
- Standalone desktop setup installs this dependency after its safety preflight.

## v1.0.0

- Initial installed-Arch niri, Firefox and OMP setup with guarded configuration changes.
- Offline live-ISO OMP bootstrap, pinned binary integrity checks and authentication guidance.
