# Arch Linux: niri + Chromium + oh-my-pi

インストール済みの Arch Linux に、niri デスクトップ、Chromium、日本語入力（Fcitx5 + Mozc）、GitHub CLI、yay、oh-my-pi (OMP) を導入する個人用スクリプトです。ディスク分割、フォーマット、OS のインストール、パスワード変更、認証情報の移送、自動ログイン、自動再起動は行いません。

## 前提

- x86_64 の **インストール済み Arch Linux**。Arch のライブ ISO では実行しません。
- ネット接続、curl、root または sudo。
- 既存の通常ユーザーと、そのユーザーのログインパスワード。
- GDM/SDDM/LightDM 等の別のログインマネージャーが未導入。
- 既存の有効なネットワークマネージャーは維持します。未設定の場合だけ NetworkManager を導入・有効化します。
- GUI パッケージ、完全なシステム更新、OMP のためのディスク空き。yay 未導入時は Go とビルド用の空きも必要です。

curl がなければ、先に `sudo pacman -Syu --needed curl` を実行してください。

## 実行

通常ユーザーでログインして、`install.sh` がないディレクトリで以下を実行します。まずファイルとしてダウンロードし、成功した場合だけ sudo で実行します。

```bash
curl -fLO https://github.com/yukimemi/arch-niri-setup/raw/v1.2.0/install.sh && sudo bash install.sh "$USER"
```

終わったら、ダウンロードしたファイルは `rm install.sh` で削除できます。

root で操作している場合は、ダウンロードした `install.sh` を `bash install.sh EXISTING_USER` で実行します。`EXISTING_USER` は作成済みの通常ユーザー名です。

初回は pacman のパッケージ確認、および設定の置き換え確認に回答します。異なる既存の niri・Fcitx5・Chromium・引き継ぎメモ・greetd 設定の置き換えと、既存のログインプロファイルへの PATH 追加は、明示的な `yes` が必要で、バックアップが保存されます。

## 導入するもの

- niri、alacritty、fuzzel、waybar、mako
- Chromium、xdg-utils、デスクトップポータル、polkit 認証エージェント
- xwayland-satellite、日本語を表示できるフォント、jp キーボード配列
- greetd + tuigreet のパスワード付きログイン
- NetworkManager（既存の他マネージャーが有効でない場合。Wi-Fi設定は `nmtui`）
- Fcitx5 + Mozc、GTK/Qt 用の入力モジュール、設定ツール
- GitHub CLI（`gh`）、git、sudo、yay
- [公式インストーラー](https://github.com/can1357/oh-my-pi#install)による最新版の OMP

Docker、開発ツール一式は追加しません。設定とユーザー向け実行ファイルは対象ユーザー所有で作成します。全 Arch パッケージを更新し、ライブ ISO、別のログインマネージャー、他ユーザー所有の設定ファイル等を検出した場合は停止します。

greetd と、採用する場合の NetworkManager は **有効化のみ**。既存のネットワーク管理構成を維持し、実行中のセッションやネット接続を切らず、再起動もしません。次の通常起動で既存ユーザーとして tuigreet にログインしてください。通常ユーザーの TTY からは `niri-session -l` でも開始できます。

## niri のキー

| キー | 動作 |
|---|---|
| Super+T | ターミナル |
| Super+D | ランチャー |
| Super+B | Chromium |
| Super+Space | IME オン／オフ切替 |
| Super+矢印 | ウィンドウ移動 |
| Super+PageUp / PageDown | ワークスペース移動 |
| Super+Shift+E | 確認付きログアウト |

困った場合は Ctrl+Alt+F2 で TTY に切り替えられます。

## 日本語入力

- **無変換**：IME オフ（英数字入力）
- **変換**：IME オン（日本語入力）
- どちらも連打で状態が逆転しません。Super+Space は従来どおり切替です。
- 日本語モードで `nihongo` → Space → Enter と入力すると「日本語」に変換・確定できます。

`~/.config/fcitx5/profile` に日本語キーボードと Mozc、`~/.config/fcitx5/config` に専用キーを設定します。自動起動は Fcitx5 パッケージ標準の XDG autostart を使い、niri の起動設定とは二重登録しません。GTK は Wayland のネイティブ入力を使用し、niri から起動するアプリに `XMODIFIERS=@im=fcitx` と `QT_IM_MODULE=fcitx` を渡します。

`~/.config/chromium-flags.conf` には Wayland IME と text-input-v3 のフラグを設定します。すでに開いている Chromium は、作業を保存して全ウィンドウを閉じ、開き直してください。サンドボックスは無効化しません。

## gh と yay

`gh` は公式 Arch パッケージです。認証はセットアップ後、通常ユーザーで実行します。

```sh
gh auth login
```

yay が既にあれば維持します。未導入時だけ `base-devel` と Go を導入し、レビュー済みの `yay.PKGBUILD` から **通常ユーザーで**ビルドします。上流 v13.0.1 のソースを SHA256 で検証した後、pacman でパッケージを導入します。

yay は Arch 公式のサポート対象ではありません。AUR のパッケージは `PKGBUILD` を確認してから、通常ユーザーで `yay -S PACKAGE` を実行してください。`sudo yay` は使いません。


## OMP 認証

niri にログイン後、**通常ユーザーのターミナルで**実行します。sudo は付けません。

```bash
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH" # 既存の端末で必要な場合
cd ~/arch-handoff
omp login openai-codex
omp --cwd . @HANDOFF.md
```

Chromium で認証します。自動で開かなければ Super+B で Chromium を開き、OMP が表示した URL を貼り付けます。同じ PC の localhost コールバックを使うため、認証が終わるまでターミナルを閉じないでください。Chromium は Arch 公式リポジトリ版で、現在の版は Wayland を標準サポートします。サンドボックス無効化の設定は追加しません。

ローカルのブラウザがないインストール済み環境では、次の別フローを使えます。

```bash
omp login openai-codex-device
```

スマホ等で https://auth.openai.com/codex/device を開き、ターミナルのワンタイムコードを入力します。ChatGPT の個人セキュリティ設定、またはワークスペース管理者側で device-code ログインを有効にする必要があります。アカウントの資格・ネットワーク・組織ポリシーによって認証が許可されない場合があります。認証は自動実行せず、既存端末の秘密情報はコピーしません。


## OMP の導入方式

最新版は公式の通常のインストーラーに任せます。セットアップはスクリプトをダウンロードして、root ではなく対象の通常ユーザーで実行します。単独で導入する場合の公式コマンドは次のとおりです（sudo 不要）。

```sh
curl -fsSL https://omp.sh/install | sh
```

公式インストーラーは、利用可能な互換 Bun があれば Bun のグローバルパッケージ、なければ SHA256 検証済みの単体バイナリを導入します。Bun/Node がないことを独自に回避する処理はありません。リリースは固定せず、バイナリ同梱・独自の取得処理・旧 `bootstrap.sh` は廃止しました。

Bash/Zsh ではログインプロファイルに `~/.local/bin` と `~/.bun/bin` を PATH へ追加します。既存ファイルへの追加は同意とバックアップを伴い、他の設定は残します。他のシェルでは、セットアップが表示する PATH の案内をそのシェルの設定に反映してください。

`~/arch-handoff` は公開の汎用メモを置く場所です。以前の会話や別 OS の認証情報はコピーしません。OMP や GitHub のログインは自動実行せず、トークンをこのリポジトリに保存しません。


## 検証範囲

- v1.2.0 の `setup-niri.sh` を、実際の x86_64 Arch/Btrfs の root を読み取り専用にし、HOME・pacman DB・サービス設定を分離した環境で最後まで実行しました。実機の設定を上書きせず、通常ユーザーへの設定保存と niri による検証を確認しました。
- 生成された Fcitx5 設定を隔離した IME セッションで読み込み、無変換オフ・変換オン・連打時の状態維持・`nihongo` →「日本語」の変換確定を確認しました。実機でもユーザーが日本語入力と専用キーを確認しています。
- レビュー済みの yay レシピを通常ユーザーで実際にビルドし、ソースの SHA256、生成パッケージ、ビルドした `yay --version` を確認しました。既存 yay の維持も確認しました。
- 公式インストーラーで通常ユーザーに OMP を導入し、生成されたログインプロファイル経由の起動を確認しました。検証時の最新版は 18.10.1 です。これは導入バージョンの固定ではありません。
- ファイル保護は実スクリプトの対象部分を通常ユーザーで単体実行し、差分のある Fcitx5 設定が同意用の端末なしで拒否されること、シンボリックリンクが拒否されること、どちらも元の内容が変わらないことを確認しました。拒否ケースの root 一括実行は管理者認証タイムアウトのため未確認です。
- 新規の tuigreet/PAM ログインや新しい OMP でのブラウザ OAuth は今回の検証対象外です。GUI のない環境での Chromium headless 描画やサンドボックス無効化を、画面表示の証明や回避策には使っていません。

## 参考

- [ArchWiki: Niri](https://wiki.archlinux.org/title/Niri)
- [ArchWiki: Greetd](https://wiki.archlinux.org/title/Greetd)
- [Fcitx: Using Fcitx 5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)
- [ArchWiki: AUR helpers](https://wiki.archlinux.org/title/AUR_helpers)
- [oh-my-pi](https://github.com/can1357/oh-my-pi)
- [OpenAI: Headless authentication](https://developers.openai.com/codex/auth#login-on-headless-devices)
