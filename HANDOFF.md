# Arch niri setup handoff

This is a generic, public note, not a saved conversation or credential file.

## User intent

Use an installed Arch Linux system with niri, Firefox, a usable terminal and oh-my-pi. Preserve existing operating systems, disk partitions, login credentials and unrelated configurations. Never assume that a fresh installation is still required.

## What these scripts do

The desktop script installs packages with a complete Arch system update, creates normal-user niri settings, installs a SHA256-verified OMP v18.10.0 in ~/arch-handoff/bin/omp, and enables greetd and NetworkManager only when selected by its safeguards. It does not partition/format disks, install Arch itself, move credentials, change passwords, enable autologin or reboot. Differing configuration replacement requires explicit consent and backups.

## First assistant action

Read-only inspection first: identify live ISO versus installed root, current user, actual root filesystem, boot mode, active network manager, existing display manager and relevant service state. Re-check reality before acting; this file is a plan, not proof of the current machine state. Explain exact affected paths and obtain explicit permission before any destructive disk or boot changes. Do not invent missing devices, keys or authentication success.

## Authentication

Inside niri, in the normal-user terminal (not sudo):

```sh
cd ~/arch-handoff
./bin/omp login openai-codex
./bin/omp --cwd . @HANDOFF.md
```

Firefox handles the same-machine localhost callback. Keep the login terminal running. If no browser opens, launch Firefox and paste the printed URL.

For an installed headless user's workspace, OMP v18.10.0 instead supports:

```sh
~/arch-handoff/bin/omp login openai-codex-device
```

Open https://auth.openai.com/codex/device on a phone or another trusted browser and enter the terminal's one-time code. Enable device-code login in personal ChatGPT security settings or via the workspace administrator first. Do not substitute the browser OAuth command for this headless flow. Account access and policy still need to permit login. Never print, commit or copy provider tokens into this repository or shared installer storage.

For live-ISO root, bootstrap uses `/run/omp-handoff` to avoid archiso's small COW overlay. Use `/run/omp-handoff/bin/omp login openai-codex-device` there, or the exact path printed by bootstrap.

Live-ISO /root is volatile; authentication and work there are not preserved by reboot. The installed normal user should authenticate afresh. This note does not migrate the Windows process, previous chat, global settings or account database.

## Desktop controls

Super+T: terminal; Super+D: launcher; Super+B: Firefox; Super+arrows: navigate; Super+PageUp/PageDown: workspaces; Super+Shift+E: confirmed logout. Ctrl+Alt+F2 switches to a recovery text console. Normal-user `niri-session -l` starts a session from a TTY when no compositor is already running.
