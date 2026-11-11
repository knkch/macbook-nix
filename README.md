# MacBook-Pro — nix-darwin Config

nix-darwin + home-manager による macOS 環境の宣言的管理。

- **ホスト**: KokinoMacBook-Pro
- **アーキテクチャ**: aarch64-darwin (Apple Silicon)
- **チャンネル**: nixpkgs-25.05-darwin (stable)

## クイックスタート

```bash
# 設定を適用
sudo darwin-rebuild switch --flake ~/.config/nix-darwin

# エイリアス（適用後）
rebuild
```

> flake は git 管理下のファイルのみ参照する。新規ファイルは `git add` してから適用。

**方針**: このリポジトリと `rebuild` だけで、何回実行しても同じ状態になるようにしている（冪等）。
macOS の仕様で自動化できない設定は「[手作業が必要な設定](#手作業が必要な設定)」にまとめてある。

## 新しい Mac にセットアップする

```bash
# 1. コマンドラインツール
xcode-select --install

# 2. Nix（公式インストーラ・マルチユーザー）
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# 3. Homebrew（cask / App Store アプリの管理に使う）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 4. このリポジトリを置く（リモートがない場合は、元の Mac からフォルダごとコピー）
git clone <リポジトリの URL> ~/.config/nix-darwin

# 5. 初回の適用（まだ darwin-rebuild がないので nix run で呼ぶ）
sudo nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake ~/.config/nix-darwin
```

- ホスト名が `KokinoMacBook-Pro`、ユーザー名が `konkichi` でない場合は `flake.nix` の `host` / `user` を直す。
- 2 回目以降は `rebuild` だけ。
- 最後に「[手作業が必要な設定](#手作業が必要な設定)」を上から順に行い、一度ログアウトする。

## ファイル構成

```
.
├── flake.nix              # inputs / outputs（user・host を一元定義）
├── flake.lock
├── CLAUDE.md              # 詳細ドキュメント
├── modules/
│   ├── system.nix         # nix 設定・ユーザー・PATH・システムパッケージ・macOS defaults
│   ├── homebrew.nix       # casks / brews / masApps / VS Code 拡張 / cleanup
│   ├── desktop.nix        # jankyborders・menubar-click-guard（sketchybar を読み込む）
│   └── sketchybar/        # sketchybar 一式
│       ├── default.nix    #   サービスとバーの設定・protected-reader の常駐
│       ├── shared.nix     #   共通部品（集中モードの一覧 focusModes など）
│       ├── lib.nix        #   各プラグインが読み込む共通関数
│       ├── action.nix     #   メニューの行を押したときの操作
│       ├── doctor.nix     #   sketchybar-doctor（点検）
│       └── plugins/       #   バーの各項目（1 ファイル 1 項目）
├── pkgs/
│   ├── menubar-click-guard/  # 画面上端のクリックを sketchybar に届ける常駐プログラム（C）
│   ├── calendar/          # 時計メニューのカレンダー画像（render.py）・予定の追加（event.js）
│   ├── focus-shortcuts/   # 集中モードの切り替え用ショートカットを用意するコマンド
│   ├── protected-reader/  # 通知・集中モードの状態を読む常駐プログラム（フルディスクアクセスはこれだけ）
│   └── runcat/            # CPU で走る猫のドット絵
└── home/
    ├── default.nix        # ユーザー情報・dotfiles・imports
    ├── packages.nix       # CLI / インフラ / クラウド
    ├── gpg.nix            # GnuPG と gpg-agent（pinentry-mac）
    ├── security.nix       # セキュリティツール群（my.security.enable）
    ├── shell.nix          # zsh・starship・atuin・zoxide・fzf・bat・eza・lazygit・direnv
    ├── git.nix            # git + delta
    ├── nixvim.nix         # Neovim（nixvim）
    ├── desktop.nix        # AeroSpace・Ghostty
    ├── music.nix          # mpd・rmpc・mpc
    ├── rmpc/              # rmpc の設定とテーマ（tokyonight）
    ├── yazi.nix           # Yazi（ファイルの開き方: 動画・音声は mpv）
    └── vscode.nix         # VS Code 表示言語
```

## 管理しているもの

| 種別 | 管理方法 |
|------|----------|
| システムパッケージ | `environment.systemPackages` (modules/system.nix) |
| ユーザー開発ツール | `home.packages` / `programs.*` (home/) |
| GUI アプリ・Claude Code | `homebrew.casks` (modules/homebrew.nix) |
| App Store アプリ | `homebrew.masApps` (modules/homebrew.nix) |
| VS Code 本体・拡張 | cask + Brewfile `vscode` 行 (modules/homebrew.nix) |
| 常駐サービス | `services.sketchybar`・protected-reader (modules/sketchybar/)、`services.jankyborders`・menubar-click-guard (modules/desktop.nix)、mpd (home/music.nix) |
| VS Code 設定 (`settings.json`) | Nix 管理外・VS Code が直接書き込み |
| 集中モードのショートカット | `focusModes` (modules/sketchybar/shared.nix) から生成し、`focus-shortcuts` で取り込む |

> Brewfile にないアプリは rebuild 時に削除される（`brew bundle cleanup`）。

## よく使う操作

| やりたいこと | 方法 |
|--------------|------|
| 設定を反映 | `rebuild` |
| CLI ツールを追加 | `home/packages.nix` に追記 → `rebuild` |
| GUI アプリを追加 | `modules/homebrew.nix` の `casks` に追記 → `rebuild` |
| 手動で入れたアプリを cask 管理へ移す | `brew install --cask --adopt <cask>` → `casks` に追記 → `rebuild`（先に adopt しないと「既にアプリがある」で失敗） |
| App Store アプリを追加 | `masApps` に `"名前" = ID;`（ID は `mas search 名前`）→ `rebuild` |
| VS Code 拡張を追加 | `modules/homebrew.nix` の `vscodeExtensions` に追記 → `rebuild` |
| Claude Code を更新 | `rebuild`（自動で最新化）または `brew upgrade --cask claude-code` |
| セキュリティツールを外す | `home/default.nix` に `my.security.enable = false;` |
| 新しい .nix ファイルを作った | `git add` してから `rebuild`（flake は git 管理下のみ参照） |
| 設定を前の状態に戻す | `git log` で確認 → `git checkout <コミット>` → `rebuild` |
| Nix のパッケージを更新 | `nix flake update` → `rebuild`（版は `flake.lock` で固定されている） |
| 集中モードを増やす | 下の「[集中モード](#集中モードsketchybar-の通知メニュー)」 |
| 集中モードのショートカットが消えた | `focus-shortcuts` →「ショートカットを追加」を押す |
| macOS を更新した・バーの一部が動かない | `sketchybar-doctor`（壊れている箇所と直し方を表示） |

> ⚠️ **Homebrew は Brewfile が唯一の正。** `brew install` で手動追加したアプリは、
> `modules/homebrew.nix` に書かないと次の `rebuild` でアンインストールされる。

## 主なツール

### デスクトップ

| ツール | 管理 | 概要 |
|--------|------|------|
| AeroSpace | cask + `programs.aerospace` | タイル型 WM。ログイン時に自動起動 |
| Sketchybar | `services.sketchybar`（パッチ版） | 左: Apple メニュー・ワークスペース 1〜9・前面アプリ（クリックでそのアプリのメニュー）/ ノッチの左: 再生中の曲・右: CPU で走る猫 / 右: カメラ（使用中のみ）・VPN・ネットワーク・Bluetooth・入力ソース・音量・電池・時計・通知（クリックでメニュー。詳細は CLAUDE.md） |
| ax-agent | launchd ユーザーエージェント | アクセシビリティが必要な操作だけを sketchybar の代わりに行う（要アクセシビリティ。sketchybar には与えない） |
| menubar-click-guard | launchd ユーザーエージェント | 画面上端・上の角のクリックが標準メニューバーに抜けるのを防ぐ（要アクセシビリティ） |
| jankyborders | `services.jankyborders` | アクティブウィンドウの枠線 |
| Ghostty | `xdg.configFile` | ターミナル（Hack Nerd Font / tokyonight） |
| macSKK | cask + dotfile | 日本語 IME（SKK-JISYO.L） |

- macOS のメニューバーは常に表示し、sketchybar（同じ高さ 33・不透明）で上から覆う（通知バナーがバーの下に出るように）。AeroSpace の隙間は 3。
- 時計メニュー: 画像で描く月カレンダー（祝日・予定の件数バッジ）、日付を押すとその日の予定、予定の追加・編集・削除（通知付き。Google / Outlook はインターネットアカウントに追加すると同期）。
- 「ディスプレイごとに個別の操作スペース」はオフ（AeroSpace 推奨、反映にはログアウトが必要）。
- Dock は自動非表示、操作スペースの自動並べ替えはオフ、Mission Control はアプリごとにグループ化。
- ステージマネージャ・壁紙クリックでデスクトップ表示・macOS 標準のウィンドウタイル（画面端ドラッグ / Option+ドラッグ）はオフ（AeroSpace と競合するため）。
- 初回のみ手動: AeroSpace にアクセシビリティ許可を与え、標準の Space を各ディスプレイ 1 つに減らす。

#### 集中モード（sketchybar の通知メニュー）

通知（ベル）のメニューで、集中モードを 1 行ずつオン / オフできる（オンは ● と緑）。
切り替えはショートカットアプリの「集中モード: <名前> オン / オフ」を実行して行う。

| やりたいこと | 方法 |
|--------------|------|
| ショートカットがそろっているか確認 | `focus-shortcuts --check` |
| 足りないショートカットを取り込む | `focus-shortcuts`（または通知メニューの「ショートカットを追加…」）→ 出てきた画面で「ショートカットを追加」 |
| 集中モードを増やす | ① システム設定 > 集中モード で追加 → ② `modules/sketchybar/shared.nix` の `focusModes` に 1 行足す（名前・識別子・表示名）→ ③ `rebuild` → ④ `focus-shortcuts` |
| 集中モードをやめる | `focusModes` から消して `rebuild` → ショートカットアプリでその 2 つを削除 |

- いま登録しているのは おやすみ・睡眠・仕事。ショートカットはフォルダ「SketchyBar」にまとめている。
- 標準モードの識別子は CLAUDE.md の「集中モード」に一覧がある。自分で作ったモードの識別子の調べ方も同じ場所。
- `rebuild` のたびにショートカットがそろっているか確認し、足りなければメッセージを出す（取り込み画面は勝手に開かない）。

#### AeroSpace キー

| キー | 動作 |
|------|------|
| `alt-h/j/k/l` | フォーカス移動 |
| `alt-shift-h/j/k/l` | ウィンドウ移動 |
| `alt-1`〜`9` | ワークスペース切り替え |
| `alt-shift-1`〜`9` | ウィンドウをワークスペースへ送る |
| `alt-f` / `alt-shift-f` | フルスクリーン / フローティング切り替え |
| `alt-/` / `alt-,` | タイル / アコーディオン切り替え |
| `alt-tab` / `alt-shift-tab` | ワークスペースを次のモニターへ / モニター間フォーカス |

### シェル

| キー・コマンド | 動作 |
|----------------|------|
| `Ctrl-R` | 履歴検索（atuin） |
| `Ctrl-T` / `Alt-C` | ファイル / ディレクトリ検索（fzf） |
| `z <dir>` | よく使うディレクトリへ移動（zoxide） |
| `ll` / `ls` | eza |
| `cat` | bat |
| `lg` | lazygit |
| `vlc-bd` | Blu-ray 再生用に OpenJDK 17 を指定して VLC を起動 |
| `music` | rmpc（音楽の操作画面）を開く |
| `youtube` | youtube-tui（YouTube の操作画面。再生は mpv） |
| `yy` | Yazi（ファイルマネージャー）。終了するとそのフォルダへ移動。写真は Enter でプレビュー、音声はターミナルで再生、動画は mpv（`O` でターミナル内再生も選べる） |

### 音楽（`home/music.nix`）

| ツール | 管理 | 概要 |
|--------|------|------|
| mpd | `services.mpd` | 再生の本体。`~/Music/MyLibrary` を CoreAudio で再生。ログイン時に起動 |
| rmpc | `programs.rmpc` | TUI（`music`）。アルバムアート表示（Kitty 方式）・tokyonight テーマ。上の帯の下に操作キーの案内（`p` 再生/一時停止・`s` 停止・`<` `>` 前/次・`b` `f` 巻き戻し/早送り・`,` `.` 音量・`x` ランダム・`z` リピート・`~` キー一覧）。帯のクリックで再生/一時停止、スクロールで音量、進行バーのクリックでその位置へ |
| mpc | `home.packages` | `mpc toggle` / `next` / `prev` / `update` |
| YouTube の曲 | rmpc `addyt` | `rmpc addyt <URL>`（rmpc の画面では `:addyt <URL>`）で YouTube の音声を落として再生リストに追加。`~/.cache/rmpc/youtube/` に保存 |
| ymuse | `home.packages`（`pkgs/ymuse`） | 無料の GUI（同じ mpd を操作）。`ymuse` か sketchybar の曲メニューから開く |

> 曲を追加したら `mpc update`。じっくり聴くときは JRiver Media Center（ビットパーフェクト・サンプリングレート自動切り替え）。

### 開発

| ツール | 管理 | 概要 |
|--------|------|------|
| Claude Code | cask `claude-code` | rebuild のたびに最新化（nixpkgs 版は更新が遅いため不使用） |
| VS Code | cask + Brewfile `vscode` 行 | 拡張は Marketplace 最新版（Pylance 含む） |
| Nixvim | `programs.nixvim` | LSP / treesitter / telescope |
| OrbStack | cask | Docker / Linux VM |
| Starship | `programs.starship` | プロンプト（Nerd Font シンボル） |
| direnv + nix-direnv | `programs.direnv` | `.envrc` に `use flake` |

### インフラ

| ツール | 概要 |
|--------|------|
| kubectl / helm / k9s | Kubernetes 操作 |
| terraform / ansible | IaC / 構成管理 |
| awscli2 / google-cloud-sdk | クラウド CLI |
| nmap / mtr / iperf3 | ネットワーク診断 |
| openlens | Kubernetes GUI |
| tableplus | データベース GUI |
| wireshark-app | パケットアナライザ（ChmodBPF 導入済み） |

### YubiKey

| ツール | 入れ方 | 概要 |
|--------|--------|------|
| ykman（yubikey-manager） | `home/packages.nix` | PIN・FIDO2・PIV・OATH の設定と管理（`ykman info` で確認） |
| Yubico Authenticator | cask | 2 段階認証コード（TOTP）の表示・管理 |
| paperkey | `home/packages.nix` | GPG の秘密鍵を紙のバックアップ用に書き出す |
| GnuPG（gpg） | `home/gpg.nix` | 署名・暗号化・SSH（gpg-agent が SSH エージェントを兼ねる）。PIN は pinentry-mac の画面で入力。git のコミットは YubiKey で署名。`gpg --card-status` で確認 |

### セキュリティ（`home/security.nix`）

| ツール | 概要 |
|--------|------|
| nuclei / nikto / gobuster | 脆弱性スキャン |
| burp-suite / caido / proxyman | Web プロキシ |
| metasploit | エクスプロイトフレームワーク |
| ghidra / radare2 | リバースエンジニアリング |
| hashcat / john | パスワード解析 |
| maltego | OSINT GUI |

### VPN / App Store

| ツール | 概要 |
|--------|------|
| WireGuard / Tailscale | VPN（App Store 版） |
| Slack / Windows App / Microsoft Excel / Brother iPrint&Scan | App Store 版 |

### Nix / Homebrew 管理外のアプリ

手動インストールのまま残しているもの（理由は [CLAUDE.md](CLAUDE.md) を参照）:
Parallels Desktop 26 / VMware Fusion 13 / MakeMKV 2.0 / e-Gov電子申請アプリケーション /
Brother ドライバ（Push Scan Tool）/ Pioneer DJ FwUpdateManager（rekordbox に同梱）

> Intel 専用（Rosetta が必要）: Maltego / e-Gov電子申請アプリケーション / Brother ドライバの常駐プロセス

## 手作業が必要な設定

macOS が外からの設定を許していないため、`rebuild` では入れられないもの。新しい Mac や作り直したときに行う。
詳しい理由とパスは [CLAUDE.md](CLAUDE.md) の「冪等性と手作業の設定」。

- [ ] **FileVault** をオンにする（システム設定 > プライバシーとセキュリティ。ディスクの暗号化。macOS の仕様で自動化できない）
- [ ] protected-reader に **フルディスクアクセス**（通知一覧・集中モードの状態）。sketchybar には与えない
- [ ] ax-agent に **アクセシビリティ**（アプリのメニュー・通知センター・ビデオエフェクト・カメラの判定・入力ソース・絵文字）。sketchybar には与えない
- [ ] sketchybar に **Bluetooth**・**カレンダー**（初回に出る確認で許可）
- [ ] menubar-click-guard と AeroSpace に **アクセシビリティ**
- [ ] 標準の Space を各ディスプレイ 1 つに減らし、ログアウト
- [ ] システム設定 > 集中モード に おやすみ・睡眠・仕事 を追加 → `focus-shortcuts` で取り込み → フォルダ「SketchyBar」へ移す
- [ ] Blu-ray を見るなら `keydb.cfg` を `~/Library/Preferences/aacs/` に置く
- [ ] Nix / Homebrew 管理外のアプリを入れる（上の一覧）

- [ ] 最後に `sketchybar-doctor` を実行して、全部 ✓ になるか確かめる

> ファイアウォールとステルスモードは `rebuild` が自動でオンにする（手作業は不要）。

> sketchybar・menubar-click-guard・protected-reader・ax-agent は、更新で場所（nix store のパス）が変わると許可を付け直す必要がある
> （ふだんの設定変更では変わらず、`nix flake update` のあとなどに起きる）。`sketchybar-doctor` で分かる。
> 古い許可は「プライバシーとセキュリティ」の一覧に残るので、ときどき削除する。
> オートメーションの一覧に sketchybar が出たら `tccutil reset AppleEvents`（画面からは外せない）。

> Homebrew は `rebuild` のたびに最新版へ更新する設定（Claude Code などを常に最新にするため）。
> そのため Homebrew で入るアプリの版だけは、実行した日によって変わる。

## 変更履歴

### 2026-10-30 メディア・アプリのメニュー・権限の分離

- **メディア**: `youtube`（youtube-tui 0.9.4。標準の機能のまま）、Yazi を home-manager 管理に（`yy`。動画・音声は mpv、写真はプレビュー）。
  rmpc のヘッダーに操作キーの案内。Rigelian（有料）を外し、無料の GUI **ymuse** に（`pkgs/ymuse` で Mac 向けに手直し）
- **sketchybar**: 前面アプリ名をクリックでそのアプリのメニュー（ファイル・編集…）を開ける。メニューの検索（⌘⇧/）
- **権限**: アクセシビリティの操作を **ax-agent** に分離。sketchybar はアクセシビリティ・フルディスクアクセス・オートメーションのどれも持たない
- **Mac の守り**: ファイアウォールとステルスモードを `rebuild` でオンに。`sketchybar-doctor` でファイアウォール・FileVault も点検

### 2026-10-29 整理・冪等性

- **整理**: sketchybar の使われていない処理（カメラ一覧、等幅のメニュー行、未使用の変数など）を削除、同じ AppleScript をまとめた。`font-hackgen`（未使用）と `xxd`（macOS 標準と重複）を削除
- **集中モード**: モードの一覧を `focusModes`（modules/desktop.nix）に一本化（今は modules/sketchybar/shared.nix）。ショートカットを用意する `focus-shortcuts` を追加し、`rebuild` で不足を確認
- **通知メニュー**: 「通知設定…」を通知の項目の下へ移し、「ショートカットを追加…」を追加
- **ドキュメント**: 新しい Mac でのセットアップ手順、手作業が必要な設定の一覧を追加
- **構成**: sketchybar を `modules/sketchybar/` に分割（1 ファイル 1 項目）。生成されるスクリプトは分割前と同一
- **権限**: 通知・集中モードの状態を読む `protected-reader` を追加し、sketchybar からフルディスクアクセスを外せるように。通知のバッジがほぼ即時に更新される
- **点検**: `sketchybar-doctor` を追加。macOS の更新で壊れうる箇所の一覧を CLAUDE.md に追加

### 2026-10-29 sketchybar の作り込み・音楽

- **sketchybar**: 再び有効化。標準メニューバー相当の項目（Apple メニュー、ネットワーク / Wi-Fi の周囲一覧、Bluetooth、VPN、音量スライダー、電池と電力モード、入力ソース、カメラ、通知一覧と集中モード）を追加。メニューは行のハイライト付き・すりガラス風
- **sketchybar**: 本体をパッチ版にしてメニューバーより手前に表示。高さ 33・不透明・ノッチ幅 186。標準メニューバーは常に表示して覆う（通知がバーの下に出る）
- **menubar-click-guard**: 画面上端・上の角のクリックが標準メニューバーに抜けるのを防ぐ常駐プログラムを追加
- **時計メニュー**: カレンダーを画像で描画（祝日・予定の件数バッジ・日付の選択）、予定の追加・編集・削除（通知付き）、カレンダーのアカウント設定への入口。Homebrew に `ical-buddy`
- **音楽**: mpd + rmpc + mpc（`home/music.nix`）、rmpc のテーマ、Rigelian（App Store）。sketchybar のノッチの左に再生中の曲、右に CPU で走る猫
- **AeroSpace**: 隙間 3、通常のウィンドウは必ずタイル、フローティングは小さな一時ウィンドウだけ
- **Brother LOGINserver**（Intel 専用）: Nix 管理外。`/Library/LaunchAgents` から plist を外して自動起動を停止

### 2026-10-29 AeroSpace 向け macOS 設定

- **sketchybar**: 無効化（設定は残置）。メニューバーを通常表示に戻し、AeroSpace の上ギャップを 37 → 5 に
- **macOS defaults**: Dock 自動非表示・`expose-group-apps` を追加、WindowManager（ステージマネージャ・標準タイル機能など）を正式オプションで無効化
- **Homebrew**: `zoom` を追加、手動インストールの JRiver Media Center を `--adopt` で取り込み `media-center` として管理
- **AeroSpace**: sketchybar への通知（`exec-on-workspace-change`）を `services.sketchybar.enable` に連動させ、無効時は呼ばないように
- **調査**: Intel 専用アプリと Nix 管理外アプリを洗い出し、一覧化

### 2026-10-20 リファクタリング

- **Claude Code**: nixpkgs 版（古く更新されない）をやめ、cask に一本化。`/opt/homebrew/bin` を `environment.systemPath` で PATH に追加（手動の PATH 追加は不要に）
- **sketchybar**: 空だった設定を実装し、nix-darwin の `services.sketchybar` で自動起動
- **jankyborders**: home-manager の launchd 定義から `services.jankyborders` へ移行
- **AeroSpace**: 設定を `programs.aerospace` で生成、ログイン時自動起動、`spans-displays` の設定ミスを修正
- **VS Code**: Nix 版と cask 版の二重インストールを解消し cask に統一。拡張も Homebrew 管理へ
- **OrbStack**: Nix から cask へ移行
- **Homebrew**: trusted cask の二重記述を解消、`wireshark` → `wireshark-app`、`brew bundle cleanup` を自動実行、App Store アプリ（Windows App / Excel / Brother）を追加
- **zsh**: compinit の二重実行と kubectl / helm 補完の毎回生成を削除（起動高速化）、`Ctrl-R` を atuin に統一、`vlc-bd` を修正
- **構成**: ユーザー名を `flake.nix` で一元定義、セキュリティツールを `home/security.nix` に分離、git 管理を開始

詳細は [CLAUDE.md](CLAUDE.md) を参照。
