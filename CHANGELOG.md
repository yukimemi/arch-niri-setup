# Changelog

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
