# Arch niri setup handoff

This is a generic, public note, not a saved conversation or credential file.

## User intent

Use an installed Arch Linux system with niri, Noctalia as the desktop shell, Chromium, a usable terminal, Japanese input with Fcitx5/Mozc, gh, yay and oh-my-pi. Preserve existing operating systems, disk partitions, login credentials and unrelated configurations. Never assume that a fresh installation is still required.

## What these scripts do

The desktop script installs packages with a complete Arch system update, creates normal-user niri, Noctalia, Fcitx5 and Chromium settings, installs the latest OMP through https://omp.sh/install as the normal user, and enables greetd and NetworkManager only when selected by its safeguards. Maintained native Noctalia replaces Waybar, mako, fuzzel and polkit-gnome in the generated desktop startup. Existing running shells, custom autostart entries and Noctalia GUI overrides are not changed; cut over at the next login and avoid duplicate user services. The official OMP installer chooses compatible existing Bun or a SHA256-verified prebuilt binary; there is no bundled or pinned OMP. Bash/Zsh login profiles receive the user-local binary PATH after consent and backup when a file already exists. Existing yay is preserved; otherwise the reviewed, SHA256-pinned yay source is built as the normal user and installed with pacman. The script does not partition/format disks, install Arch itself, move credentials, change passwords, enable autologin or reboot. Differing configuration replacement requires explicit consent and backups.

## First assistant action

Read-only inspection first: identify live ISO versus installed root, current user, actual root filesystem, boot mode, active network manager, existing display manager and relevant service state. Re-check reality before acting; this file is a plan, not proof of the current machine state. Explain exact affected paths and obtain explicit permission before any destructive disk or boot changes. Do not invent missing devices, keys or authentication success.

## Authentication

Inside niri, in the normal-user terminal (not sudo):

```sh
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH" # If needed in an existing terminal
cd ~/arch-handoff
omp login openai-codex
omp --cwd . @HANDOFF.md
```

Chromium handles the same-machine localhost callback. Keep the login terminal running. If no browser opens, launch Chromium and paste the printed URL. Use the normal user and keep the browser sandbox enabled.

For an installed headless user's workspace, use the separate device-code flow:

```sh
omp login openai-codex-device
```

Open https://auth.openai.com/codex/device on a phone or another trusted browser and enter the terminal's one-time code. Enable device-code login in personal ChatGPT security settings or via the workspace administrator first. Do not substitute the browser OAuth command for this headless flow. Account access and policy still need to permit login. Never print, commit or copy provider tokens into this repository or shared installer storage.


Live-ISO /root is volatile; authentication and work there are not preserved by reboot. The installed normal user should authenticate afresh. This note does not migrate the Windows process, previous chat, global settings or account database.

## Desktop controls

Window/workspace controls follow niri 26.04's official default bindings. Super+arrows or H/J/K/L: focus; add Ctrl: move the column/window; add Shift instead: focus another monitor; Ctrl+Shift: move the column to another monitor. Super+1..9 or PageUp/PageDown: workspaces; Super+O: overview; Super+V: floating; Super+Comma/Period: consume/expel windows in a column; Super+Shift+Slash: hotkey overlay. Application additions: Super+T: terminal; Super+D: Noctalia launcher; Super+S: control center; Super+Ctrl+Comma: Noctalia settings; Super+Ctrl+V: Noctalia clipboard history; Super+B: Chromium; Super+Space: IME toggle. Super+Shift+E: confirmed logout. Brightness keys use Noctalia in 10% steps with a 5% floor and automatic device discovery. Noctalia captures: Print: region; Ctrl+Print: focused screen; Alt+Print: frozen-screen annotation (replaces window-only capture). In the editor, Ctrl+S saves, Ctrl+C copies and Escape cancels. Ctrl+Alt+F2 switches to a recovery text console. Normal-user `niri-session -l` starts a session from a TTY when no compositor is already running.

## Japanese input and tools

Fcitx5 + Mozc starts via the package's XDG autostart in the niri systemd session. Muhenkan (無変換) turns IME off; Henkan (変換) turns IME on; repeated presses retain that state. Super+Space toggles. With Japanese input enabled, type `nihongo`, Space, then Enter to convert and commit `日本語`.

Relevant user files: `~/.config/niri/config.kdl`, `~/.config/noctalia/config.toml`, `~/.config/fcitx5/config`, `~/.config/fcitx5/profile`, and `~/.config/chromium-flags.conf`. Noctalia owns notifications and polkit authentication; its screenshot-saved notifications expire after 5000 ms. `[shell.screenshot]` saves region/fullscreen PNGs to `~/Pictures/Screenshots/` and copies them to the clipboard; the settings UI can change this policy. Noctalia clipboard history is enabled with 100 unpinned entries. Copied secrets can remain: remove sensitive entries in the panel. Persistent encrypted history requires an unlocked Secret Service provider; without one history works for the current session only. The installer does not provision keyrings/keys or change PAM. Existing applications retain their old environment; save work and reopen Chromium for its Wayland IME flags to take effect.

Authenticate GitHub with `gh auth login` as the normal user, never sudo. Run yay as the normal user and review AUR PKGBUILDs before installing. Neither tool imports credentials from another machine.
