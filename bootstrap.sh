#!/usr/bin/env bash
# Run with bash; the bundle may reside on a non-executable FAT32 volume.
set -euo pipefail
umask 077

fail() {
    printf 'bootstrap: %s\n' "$*" >&2
    exit 1
}
[[ $# -le 1 ]] || fail 'Usage: bootstrap.sh [--install-only|--login]'
mode=${1:-start}
case "$mode" in
    start|--install-only|--login) ;;
    *) fail "Unknown option: $mode" ;;
esac


[[ $(uname -s) == Linux ]] || fail 'Linux is required.'
[[ $(uname -m) == x86_64 ]] || fail 'An x86_64 Linux system is required.'
for command in sha256sum cmp cp mkdir mktemp chmod ln rm stat dirname; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command is unavailable: $command"
done

bundle=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
binary="$bundle/omp-linux-x64"
notes="$bundle/HANDOFF.md"
expected_sha256=d5c6f92cabc231b4fb94c47322fc67b3c473c3b107339237a4b2f16505b38342
[[ -f "$binary" && -r "$binary" ]] || fail "Unreadable bundled binary: $binary"
[[ -f "$notes" && -r "$notes" ]] || fail "Unreadable handoff notes: $notes"

matches_binary() {
    local digest
    digest=$(sha256sum < "$1") || return 1
    [[ ${digest%% *} == "$expected_sha256" ]]
}

matches_binary "$binary" || fail 'Bundled binary checksum does not match the pinned v18.10.0 release.'
[[ ${HOME:-} == /* && -d "$HOME" ]] || fail 'HOME must name an existing absolute directory.'
# archiso's default overlay can be only 256 MiB; the standalone binary is larger.
# Keep the live root's executable on /run's separate tmpfs, not the small COW layer.
if [[ $EUID == 0 && -d /run/archiso ]]; then
    workspace=/run/omp-handoff
else
    workspace="${HOME%/}/arch-handoff"
fi
bin_dir="$workspace/bin"
installed="$bin_dir/omp"
installed_notes="$workspace/HANDOFF.md"

# Refuse existing symlinks or non-private directories rather than repurpose them.
for directory in "$workspace" "$bin_dir"; do
    if [[ -e "$directory" || -L "$directory" ]]; then
        [[ -d "$directory" && ! -L "$directory" && -O "$directory" ]] || fail "Unsafe existing directory: $directory"
        [[ $(stat -c '%a' -- "$directory") == 700 ]] || fail "Existing directory must have mode 700: $directory"
    else
        mkdir -m 700 -- "$directory" || fail "Cannot create private directory: $directory"
    fi
done

# Preflight both destinations before installing either file.
if [[ -e "$installed" || -L "$installed" ]]; then
    [[ -f "$installed" && ! -L "$installed" && -O "$installed" && -r "$installed" ]] || fail "Unsafe existing binary: $installed"
    matches_binary "$installed" || fail "Refusing to replace a nonmatching file: $installed"
fi
if [[ -e "$installed_notes" || -L "$installed_notes" ]]; then
    [[ -f "$installed_notes" && ! -L "$installed_notes" && -O "$installed_notes" && -r "$installed_notes" ]] || fail "Unsafe existing notes: $installed_notes"
    cmp -s -- "$notes" "$installed_notes" || fail "Refusing to replace nonmatching notes: $installed_notes"
fi

temporary=''
trap 'if [[ -n "$temporary" ]]; then rm -f -- "$temporary"; fi' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ! -e "$installed" ]]; then
    temporary=$(mktemp "$bin_dir/.omp.XXXXXXXX")
    cp -- "$binary" "$temporary"
    matches_binary "$temporary" || fail 'Copied binary checksum mismatch.'
    chmod 700 -- "$temporary"
    # A hard link publishes the complete file atomically and never overwrites.
    ln -- "$temporary" "$installed" || fail "Cannot safely install binary: $installed"
    rm -- "$temporary"
    temporary=''
else
    # Only the already checksum-matching executable has its mode adjusted.
    chmod 700 -- "$installed"
fi

if [[ ! -e "$installed_notes" ]]; then
    temporary=$(mktemp "$workspace/.HANDOFF.XXXXXXXX")
    cp -- "$notes" "$temporary"
    cmp -s -- "$notes" "$temporary" || fail 'Copied notes do not match the bundle.'
    ln -- "$temporary" "$installed_notes" || fail "Cannot safely install notes: $installed_notes"
    rm -- "$temporary"
    temporary=''
fi

printf 'Installed workspace: %s\n' "$workspace"
if ! "$installed" --version; then
    fail 'The installed omp cannot run. Check architecture, runtime libraries, and whether HOME is on a noexec filesystem. No disk layout was changed.'
fi

cat <<'GUIDANCE'

Arch ライブ ISO の初回作業用です。インストール後の Arch でも使用できます。
ライブ ISO の /root 以下は通常 RAM 上なので、再起動すると作業内容は消えます。
このスクリプトはパッケージ導入・ネットワークダウンロード・ディスク変更・
Windows の認証情報の書き出しや移行を行いません。
LLM との会話にはネットワーク接続と利用可能な認証が必要です。
--login を指定すると、スマホ等のブラウザーで完了できる device-code 認証を開始します。
事前に ChatGPT のセキュリティ設定またはワークスペース管理者側で device-code ログインを有効にしてください。
別途ログインする場合:
GUIDANCE
printf '  "%s" login openai-codex-device\n' "$installed"
[[ "$mode" != --install-only ]] || exit 0
if [[ "$mode" == --login ]]; then
    "$installed" login openai-codex-device
fi

cd -- "$workspace"
exec "$installed" --model openai-codex/gpt-6.1-sol --cwd "$workspace" '@HANDOFF.md' \
    'HANDOFF.mdを読み、Archの安全な新規インストール作業を引き継いでください。まず読み取り専用の調査だけを行い、ライブISOかインストール済み環境かを確認してください。現在のディスク識別情報・PARTUUID・パーティション配置を実機で再確認し、Windowsと既存EFIを保護してください。インストール済みなら再インストールを前提にしないでください。これ以降の破壊的変更（パーティション変更、フォーマット、消去、ブート設定変更など）は、具体的な対象と影響を説明し、必ず私の明示的な許可を得てから行ってください。'
