# Arch Linux: niri + Firefox + oh-my-pi

インストール済みの Arch Linux に、niri デスクトップと Firefox、oh-my-pi (OMP) を導入する個人用スクリプトです。ディスク分割、フォーマット、OS のインストール、パスワード変更、認証情報の移送、自動ログイン、自動再起動は行いません。

## 前提

- x86_64 の **インストール済み Arch Linux**。Arch のライブ ISO では実行しません。
- ネット接続、curl、root または sudo。
- 既存の通常ユーザーと、そのユーザーのログインパスワード。
- GDM/SDDM/LightDM 等の別のログインマネージャーが未導入。
- 既存の有効なネットワークマネージャーは維持します。未設定の場合だけ NetworkManager を導入・有効化します。
- GUI パッケージ、完全なシステム更新、OMP バイナリ約263 MiB のためのディスク空き。

curl がなければ、先に `sudo pacman -Syu --needed curl` を実行してください。

## 実行

通常ユーザーでログインして、以下を一度実行します。まずファイルとしてダウンロードし、成功した場合だけ sudo で実行します。

```bash
(f=$(mktemp) && trap 'rm -f "$f"' EXIT && curl -fsSL https://raw.githubusercontent.com/yukimemi/arch-niri-setup/v1.0.0/install.sh -o "$f" && sudo bash "$f" "$USER")
```

root で操作している場合は、ダウンロードした `install.sh` を `bash install.sh EXISTING_USER` で実行します。`EXISTING_USER` は作成済みの通常ユーザー名です。

初回は pacman のパッケージ確認、および greetd 設定の置き換え確認に回答します。異なる既存設定の置き換えは、明示的な `yes` が必要で、バックアップが保存されます。

## 導入するもの

- niri、alacritty、fuzzel、waybar、mako
- Firefox、xdg-utils、デスクトップポータル、polkit 認証エージェント
- xwayland-satellite、日本語を表示できるフォント、jp キーボード配列
- greetd + tuigreet のパスワード付きログイン
- NetworkManager（既存の他マネージャーが有効でない場合。Wi-Fi設定は `nmtui`）
- SHA256 を照合した OMP v18.10.0（Bun/Node の別途導入は不要）

日本語 IME、Docker、開発ツール一式は追加しません。設定と実行ファイルは対象ユーザー所有で作成します。全 Arch パッケージを更新し、ライブ ISO、別のログインマネージャー、他ユーザー所有の設定ファイル等を検出した場合は停止します。

greetd と、採用する場合の NetworkManager は **有効化のみ**。既存のネットワーク管理構成を維持し、実行中のセッションやネット接続を切らず、再起動もしません。次の通常起動で既存ユーザーとして tuigreet にログインしてください。通常ユーザーの TTY からは `niri-session -l` でも開始できます。

## niri のキー

| キー | 動作 |
|---|---|
| Super+T | ターミナル |
| Super+D | ランチャー |
| Super+B | Firefox |
| Super+矢印 | ウィンドウ移動 |
| Super+PageUp / PageDown | ワークスペース移動 |
| Super+Shift+E | 確認付きログアウト |

困った場合は Ctrl+Alt+F2 で TTY に切り替えられます。

## OMP 認証

niri にログイン後、**通常ユーザーのターミナルで**実行します。sudo は付けません。

```bash
cd ~/arch-handoff
./bin/omp login openai-codex
./bin/omp --cwd . @HANDOFF.md
```

Firefox で認証します。自動で開かなければ Super+B で Firefox を開き、OMP が表示した URL を貼り付けます。同じ PC の localhost コールバックを使うため、認証が終わるまでターミナルを閉じないでください。

ローカルのブラウザがないインストール済み環境では、次の別フローを使えます。

```bash
~/arch-handoff/bin/omp login openai-codex-device
```

スマホ等で https://auth.openai.com/codex/device を開き、ターミナルのワンタイムコードを入力します。ChatGPT の個人セキュリティ設定、またはワークスペース管理者側で device-code ログインを有効にする必要があります。アカウントの資格・ネットワーク・組織ポリシーによって認証が許可されない場合があります。認証は自動実行せず、既存端末の秘密情報はコピーしません。

ライブISOのrootでbootstrapを実行した場合は `/run/omp-handoff/bin/omp login openai-codex-device` を使います。表示された実際のインストール先を確認してください。

## オフラインの OMP 起動スクリプト

`bootstrap.sh` は、同じディレクトリに公式 Linux バイナリ `omp-linux-x64` と `HANDOFF.md` を置いた場合の補助スクリプトです。バイナリをこの Git リポジトリには保存しません。

```bash
bash bootstrap.sh --install-only  # 検証・インストールのみ
bash bootstrap.sh --login         # device-code 認証後、引き継ぎ会話を開始
bash bootstrap.sh                 # 既存認証で会話を開始
```

ライブISOの小さなCOW領域にバイナリを置かないよう、live/rootでは `/run/omp-handoff` を使います。/runとliveの/rootは再起動すると消えます。認証情報を移す処理は含みません。インストール後の通常ユーザーでは改めて認証します。公開HANDOFF.mdは汎用メモで、以前の会話そのものや個別PCの情報は含みません。

## 参考

- [ArchWiki: Niri](https://wiki.archlinux.org/title/Niri)
- [ArchWiki: Greetd](https://wiki.archlinux.org/title/Greetd)
- [oh-my-pi](https://github.com/can1357/oh-my-pi)
- [OpenAI: Headless authentication](https://developers.openai.com/codex/auth#login-on-headless-devices)
