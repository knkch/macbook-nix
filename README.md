# KokinoMacBook-Pro — nix-darwin Config

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

## ファイル構成

```
.
├── flake.nix              # inputs / outputs（user・host を一元定義）
├── flake.lock
├── CLAUDE.md              # 詳細ドキュメント
├── modules/
│   ├── system.nix         # nix 設定・ユーザー・PATH・システムパッケージ・macOS defaults
│   ├── homebrew.nix       # casks / brews / masApps / VS Code 拡張 / cleanup
│   └── desktop.nix        # sketchybar・jankyborders（launchd サービス）
└── home/
    ├── default.nix        # ユーザー情報・dotfiles・imports
    ├── packages.nix       # CLI / インフラ / クラウド
    ├── security.nix       # セキュリティツール群（my.security.enable）
    ├── shell.nix          # zsh・starship・atuin・zoxide・fzf・bat・eza・lazygit・direnv
    ├── git.nix            # git + delta
    ├── nixvim.nix         # Neovim（nixvim）
    ├── desktop.nix        # AeroSpace・Ghostty
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
| 常駐サービス | `services.sketchybar` / `services.jankyborders` (modules/desktop.nix) |
| VS Code 設定 (`settings.json`) | Nix 管理外・VS Code が直接書き込み |

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

> ⚠️ **Homebrew は Brewfile が唯一の正。** `brew install` で手動追加したアプリは、
> `modules/homebrew.nix` に書かないと次の `rebuild` でアンインストールされる。

## 主なツール

### デスクトップ

| ツール | 管理 | 概要 |
|--------|------|------|
| AeroSpace | cask + `programs.aerospace` | タイル型 WM。ログイン時に自動起動 |
| Sketchybar | `services.sketchybar` | 左: ワークスペース 1〜9・前面アプリ / 右: 音量・電池・時計 |
| jankyborders | `services.jankyborders` | アクティブウィンドウの枠線 |
| Ghostty | `xdg.configFile` | ターミナル（Hack Nerd Font / tokyonight） |
| macSKK | cask + dotfile | 日本語 IME（SKK-JISYO.L） |

- macOS のメニューバーは自動非表示（sketchybar と重ならないように）。AeroSpace の上ギャップはバーの高さに合わせて 37。
- 「ディスプレイごとに個別の操作スペース」はオフ（AeroSpace 推奨、反映にはログアウトが必要）。
- Dock は自動非表示、操作スペースの自動並べ替えはオフ、Mission Control はアプリごとにグループ化。
- ステージマネージャ・壁紙クリックでデスクトップ表示・macOS 標準のウィンドウタイル（画面端ドラッグ / Option+ドラッグ）はオフ（AeroSpace と競合するため）。
- 初回のみ手動: AeroSpace にアクセシビリティ許可を与え、標準の Space を各ディスプレイ 1 つに減らす。

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

## 変更履歴

### 2026-10-29 sketchybar 再有効化

- **sketchybar**: 再び有効化。メニューバーを自動非表示に、AeroSpace の上ギャップを 5 → 37 に
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
