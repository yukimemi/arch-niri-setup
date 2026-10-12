# Changelog

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
