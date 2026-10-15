# Arch Linux: niri + Noctalia + Chromium + oh-my-pi

インストール済みの Arch Linux に、niri と Noctalia のデスクトップ、Chromium、日本語入力（Fcitx5 + Mozc）、GitHub CLI、yay、oh-my-pi (OMP) を導入する個人用スクリプトです。ディスク分割、フォーマット、OS のインストール、パスワード変更、認証情報の移送、自動ログイン、自動再起動は行いません。

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
curl -fLO https://github.com/yukimemi/arch-niri-setup/raw/v1.6.0/install.sh && sudo bash install.sh "$USER"
```

終わったら、ダウンロードしたファイルは `rm install.sh` で削除できます。

root で操作している場合は、ダウンロードした `install.sh` を `bash install.sh EXISTING_USER` で実行します。`EXISTING_USER` は作成済みの通常ユーザー名です。

初回は pacman のパッケージ確認、および設定の置き換え確認に回答します。異なる既存の niri・Noctalia・Fcitx5・Chromium・引き継ぎメモ・greetd 設定の置き換えと、既存のログインプロファイルへの PATH 追加は、明示的な `yes` が必要で、バックアップが保存されます。

## 導入するもの

- niri、Noctalia v5+、alacritty、UPower（ノートPCのバッテリー情報）
- Chromium、xdg-utils、デスクトップポータル
- xwayland-satellite、日本語を表示できるフォント、jp キーボード配列
- greetd + tuigreet のパスワード付きログイン
- NetworkManager（既存の他マネージャーが有効でない場合。Wi-Fi設定は `nmtui`）
- Fcitx5 + Mozc、GTK/Qt 用の入力モジュール、設定ツール
- GitHub CLI（`gh`）、git、sudo、yay
- [公式インストーラー](https://github.com/can1357/oh-my-pi#install)による最新版の OMP

Docker、開発ツール一式は追加しません。設定とユーザー向け実行ファイルは対象ユーザー所有で作成します。全 Arch パッケージを更新し、ライブ ISO、別のログインマネージャー、他ユーザー所有の設定ファイル等を検出した場合は停止します。

greetd と、採用する場合の NetworkManager は **有効化のみ**。既存のネットワーク管理構成を維持し、実行中のセッションやネット接続を切らず、再起動もしません。次の通常起動で既存ユーザーとして tuigreet にログインしてください。通常ユーザーの TTY からは `niri-session -l` でも開始できます。

## Noctalia

Arch 公式 extra の `noctalia` を使います。旧 Quickshell 版ではなく、現行のネイティブ版です。バー、ランチャー、通知、管理者認証は Noctalia にまとめ、Waybar・mako・fuzzel・polkit-gnome は新規導入・自動起動しません。既に入っている旧パッケージは削除しません。

`~/.config/noctalia/config.toml` は日本語 UI、ネイティブ通知と polkit、明るさの下限5%、スクショ通知の5秒タイムアウト、ネイティブのスクショとクリップボード履歴を設定します。明るさはディスプレイ／バックライトを自動検出し、特定の実機の `eDP-1` や `intel_backlight` を公開設定に固定しません。

既存の Noctalia GUI 設定 `~/.local/state/noctalia/settings.toml` と他の TOML ファイルは保持します。GUI の上書き設定は生成した基本設定より優先するため、見た目や機能が想定と違う場合は Noctalia の設定画面で確認してください。

セットアップは実行中のバーや通知デーモンを停止しません。旧構成のセッションでは作業を保存してログアウト／再ログインし、niri の新しい自動起動設定へ切り替えてください。別途作った旧シェルのユーザーサービスや XDG autostart は変更しないので、Noctalia と二重起動しないよう事前に無効化してください。


## niri のキー

ウィンドウ・ワークスペース操作は、niri 26.04 の公式 `default-config.kdl` の有効な標準操作に合わせています。アプリ起動は Noctalia 用に差し替え、日本語入力・Chromium・明るさ操作を追加しています。公式サンプルの外部アプリ用ロック・音量・メディア操作は、この変更では追加しません。

旧構成からの変更：`Super+Shift+矢印` はウィンドウ移動ではなくモニターへのフォーカス移動になります。ウィンドウ／列の移動は `Super+Ctrl+矢印` です。Noctalia 設定は列操作と衝突しない `Super+Ctrl+,` に移しました。

| キー | 動作 |
|---|---|
| CapsLock | 追加の Ctrl（元の Ctrl も維持） |
| Super+T | ターミナル |
| Super+D | Noctalia ランチャー |
| Super+S | Noctalia コントロールセンター |
| Super+Ctrl+, | Noctalia 設定 |
| Super+B | Chromium |
| Super+Space | IME オン／オフ切替 |
| Super+Ctrl+V | Noctalia クリップボード履歴 |
| 明るさ小／大キー | Noctalia で10%刻み（下限5%） |
| Print | Noctalia スクショ範囲選択 |
| Ctrl+Print | Noctalia で選択中の画面を撮影 |
| Alt+Print | Noctalia の撮影＋注釈編集 |
| Super+(矢印 / H・J・K・L) | フォーカス移動（左右は列、上下は列内のウィンドウ） |
| Super+Ctrl+(矢印 / H・J・K・L) | 列／ウィンドウを移動 |
| Super+Shift+(矢印 / H・J・K・L) | 別モニターへフォーカス |
| Super+Ctrl+Shift+(矢印 / H・J・K・L) | 列を別モニターへ移動 |
| Super+(PageUp / PageDown / I / U) | ワークスペースへフォーカス |
| Super+Ctrl+(PageUp / PageDown / I / U) | 列を別ワークスペースへ移動 |
| Super+Shift+(PageUp / PageDown / I / U) | ワークスペースの順序を変更 |
| Super+1〜9 | 番号でワークスペースへフォーカス |
| Super+Ctrl+1〜9 | 列を指定ワークスペースへ移動 |
| Super+O | 一覧表示（Overview） |
| Super+Q | ウィンドウを閉じる（押しっぱなしで連続実行しない） |
| Super+, / Super+. | 右のウィンドウを列に取り込む／列の下端を外へ出す |
| Super+[ / Super+] | 選択中のウィンドウを左右の列へ取り込む／外へ出す |
| Super+R / Super+Shift+R | 列幅プリセットを順／逆に切替 |
| Super+F / Super+Shift+F | 列の最大化／ウィンドウの全画面表示 |
| Super+M | ウィンドウを画面の端まで最大化 |
| Super+C | 列を画面中央へ |
| Super+- / Super+= | 列幅を10%ずつ縮小／拡大 |
| Super+V | フローティングとタイル配置を切替 |
| Super+Shift+V | フローティング／タイル側へフォーカス切替 |
| Super+W | 列のタブ表示を切替 |
| Super+Shift+/ | ショートカット一覧 |
| Super+Shift+E | 確認付きログアウト |

困った場合は Ctrl+Alt+F2 で TTY に切り替えられます。
公式標準の Home/End、ホイール操作、ウィンドウ高さ調整、ショートカット抑止の切替、Ctrl+Alt+Delete の確認付きログアウト、Super+Shift+P の画面消灯も含みます。設定の全定義は `setup-niri.sh` の `binds` を参照してください。
スクショはすべて Noctalia のネイティブ機能を呼びます。`[shell.screenshot]` で保存先を `~/Pictures/Screenshots/` にし、範囲・全画面撮影は PNG 保存とクリップボードへのコピーを両方行います。新規の保存ディレクトリは対象ユーザー所有・700 権限です。保存先や編集動作は Noctalia の設定画面から変更できます。コンポジターの `wlr-screencopy` 対応が必要で、niri 26.04 で実際に撮影を確認しています。

**Alt+Print は以前の「ウィンドウ単体撮影」から「画面を撮って注釈編集」へ変更しました。** 注釈画面では矢印・文字・ぼかし・切り抜きなどを使えます。Ctrl+S で保存、Ctrl+C でコピーし、成功すると編集画面を閉じます。Escape はキャンセルです。Noctalia にはウィンドウ単体撮影コマンドがないため、その旧割り当ては残しません。

## クリップボード履歴

`Super+Ctrl+V` で Noctalia の履歴を開き、文章や画像を検索・選択して再利用できます。ピン留めを除く履歴は100件までです。通常のコピー＆ペーストも使えます。別の履歴デーモンは導入しません。

コピーしたパスワードやトークンも残る可能性があります。不要な項目は履歴パネルから削除してください。パスワードマネージャーが機密マーカーを付けない場合、終了後もコピー内容が残ることがあります。

履歴の永続保存は Noctalia 標準の Secret Service 経由で暗号化され、利用可能なキーリングが必要です。**プロバイダーがない・ロック中の場合、履歴は現在のセッション内のみで、終了すると失われます。** セットアップはキーリングの導入、PAM 変更、鍵の生成・共有、既存の秘密情報の移行を行いません。永続化したい場合は GNOME Keyring・KWallet・KeePassXC などのプロバイダーを別途設定し、Noctalia の「履歴ストレージ」で状態を確認してください。


## 日本語入力

日本語配列を維持し、niri の XKB オプション `ctrl:nocaps` で **CapsLock を追加の Ctrl** にします。Ctrl と CapsLock の交換ではなく、CapsLock による英大文字固定はなくなります。適用範囲は niri セッション内で、TTY や greetd のキーマップは変更しません。

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

- v1.6.0 は、実行中の niri が Wayland クライアントへ配信する実際のキーマップを取得して確認しました。変更前の CAPS は `Eisu_toggle`、変更後は `Control_L` です。CAPS と既存の左 Ctrl の両方で Ctrl 修飾の押下／解放が成立し、Caps Lock の固定が発生しないことを libxkbcommon の状態遷移で確認しました。実機設定とセットアップ生成設定の niri 検証も通過しました。物理キー押下とセットアップ全体の root 再実行は未確認です。
- v1.5.0 は niri 26.04 / Noctalia 5.2.1 で、全画面・マウスでの範囲選択・矢印注釈の保存・範囲選択のキャンセルを実際に操作しました。キーボードフォーカスを持つ GTK/Wayland アプリで、撮影した PNG の保存データと実際の `image/png` クリップボードデータが一致しました。別の実アプリからコピーした2つの文章を履歴画面で確認し、古い文章を選ぶとライブのクリップボードへ戻ることも確認しました。Noctalia の撮影通知は5.000〜5.002秒で期限切れになりました。キーリングを使った再ログイン後の履歴復元と、v1.5.0 全体の root 実行は未確認です。
- v1.4.0 の実機設定とセットアップが生成した設定は niri の検証を通過しました。通常セッションへ影響する `--session` やシェル自動起動を使わない隔離したネスト環境で、実際のウィンドウを使い、フォーカス・列移動・列の取り込み／分離・フローティング・ワークスペース間移動・Overview を IPC 経由で確認しました。Overview の実画面も確認しています。自動キー入力ではショートカットを発火できず、物理キーおよび複数モニターでの動作は未確認です。
- v1.3.0 の実スクリプトのステージング処理を通常ユーザーで実行し、生成された niri・Noctalia 設定を実際のコマンドで検証しました。公開設定はバックライト名を固定せず、クリップボード履歴を無効にし、スクショ通知を5秒に設定しています。
- 実機の Noctalia バーと日本語ランチャーを画面で確認しました。公開設定と同じ `brightness-up/down current 10%` が実バックライトを変更し、元の値へ戻せることを確認しました。実際のスクショ通知は5.01秒で期限切れになりました。
- v1.2.0 の `setup-niri.sh` を、実際の x86_64 Arch/Btrfs の root を読み取り専用にし、HOME・pacman DB・サービス設定を分離した環境で最後まで実行しました。実機の設定を上書きせず、通常ユーザーへの設定保存と niri による検証を確認しました。
- 生成された Fcitx5 設定を隔離した IME セッションで読み込み、無変換オフ・変換オン・連打時の状態維持・`nihongo` →「日本語」の変換確定を確認しました。実機でもユーザーが日本語入力と専用キーを確認しています。
- レビュー済みの yay レシピを通常ユーザーで実際にビルドし、ソースの SHA256、生成パッケージ、ビルドした `yay --version` を確認しました。既存 yay の維持も確認しました。
- 公式インストーラーで通常ユーザーに OMP を導入し、生成されたログインプロファイル経由の起動を確認しました。検証時の最新版は 18.10.1 です。これは導入バージョンの固定ではありません。
- ファイル保護は実スクリプトの対象部分を通常ユーザーで実行し、差分のある Noctalia 設定が同意用の端末なしで拒否されること、シンボリックリンクが拒否されること、元の内容とリンクが変わらないことを確認しました。v1.3.0 全体の root 隔離実行は管理者認証タイムアウトのため未確認です。
- 新規の tuigreet/PAM ログインや新しい OMP でのブラウザ OAuth は今回の検証対象外です。GUI のない環境での Chromium headless 描画やサンドボックス無効化を、画面表示の証明や回避策には使っていません。

## 参考

- [ArchWiki: Niri](https://wiki.archlinux.org/title/Niri)
- [ArchWiki: Greetd](https://wiki.archlinux.org/title/Greetd)
- [Noctalia: Installation](https://docs.noctalia.dev/noctalia/getting-started/installation/)
- [Noctalia: Running Noctalia](https://docs.noctalia.dev/noctalia/getting-started/running-the-shell/)
- [Noctalia: Screenshots](https://docs.noctalia.dev/noctalia/bar/widgets/screenshot/)
- [Noctalia: Secret Service & keyrings](https://docs.noctalia.dev/noctalia/configuration/secret-service/)
- [Fcitx: Using Fcitx 5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)
- [ArchWiki: AUR helpers](https://wiki.archlinux.org/title/AUR_helpers)
- [oh-my-pi](https://github.com/can1357/oh-my-pi)
- [OpenAI: Headless authentication](https://developers.openai.com/codex/auth#login-on-headless-devices)
