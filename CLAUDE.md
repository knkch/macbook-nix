# nix-darwin Configuration — KokinoMacBook-Pro

nix-darwin + home-manager による macOS 環境の宣言的管理（git 管理）。
ホスト: `KokinoMacBook-Pro` / アーキテクチャ: `aarch64-darwin` / ユーザー: `konkichi`

## 適用コマンド

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
# または
rebuild   # zsh エイリアス
```

- flake は **git に add されたファイルしか見えない**。新規ファイルは `git add` してから rebuild。
- ビルドだけ確認: `nix build .#darwinConfigurations.KokinoMacBook-Pro.system --no-link`
- 整形: `nix fmt`

---

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `flake.nix` | inputs / outputs。`user` / `host` はここで一元定義し `specialArgs` で各モジュールへ |
| `modules/system.nix` | nix 設定・ユーザー・PATH・システムパッケージ・macOS defaults（Dock / Spaces / WindowManager 含む）・GC |
| `modules/homebrew.nix` | Homebrew casks / brews / masApps / VS Code 拡張 / cleanup |
| `modules/desktop.nix` | 常駐サービス: sketchybar（設定・プラグイン込み）、jankyborders |
| `home/default.nix` | ユーザー情報・dotfiles・imports |
| `home/packages.nix` | 一般 CLI / インフラ / クラウドツール |
| `home/security.nix` | セキュリティツール群（`my.security.enable` で一括オン・オフ） |
| `home/shell.nix` | zsh・starship・atuin・zoxide・fzf・bat・eza・lazygit・direnv |
| `home/git.nix` | git + delta |
| `home/nixvim.nix` | Neovim（nixvim）全設定 |
| `home/desktop.nix` | AeroSpace 設定・Ghostty |
| `home/vscode.nix` | VS Code の表示言語のみ（本体・拡張は Homebrew） |

### 配置の原則

| 種別 | 置き場所 |
|------|----------|
| システム全体・ネットワーク CLI | `environment.systemPackages` (modules/system.nix) |
| ユーザー開発ツール | `home.packages` / `programs.*` (home/*.nix) |
| 頻繁に更新したい CLI / GUI アプリ | `homebrew.casks` (modules/homebrew.nix) |
| GUI アプリ（App Store） | `homebrew.masApps` (modules/homebrew.nix) |
| 常駐サービス | nix-darwin `services.*` (modules/desktop.nix) |
| dotfiles | `home.file.*` / `xdg.configFile.*` / `programs.*` |

---

## Homebrew の方針

- **Brewfile が唯一の正**。rebuild 時に `brew bundle cleanup --force` が走り、
  Brewfile にない cask / formula / App Store アプリ / VS Code 拡張は **アンインストールされる**（zap はしない）。
  → 手動で `brew install` したものは必ず `modules/homebrew.nix` にも追加する。
  - Homebrew 7 で `brew bundle --cleanup` フラグが廃止され、nix-darwin 25.05 の
    `onActivation.cleanup` が使えないため、activation script で自前実行している。
- `onActivation.autoUpdate` / `upgrade` が有効 → rebuild のたびに cask も最新化される。
- サードパーティ tap の cask（cmux / chiaki-ng / aerospace）は Homebrew 7 の要件で
  `trusted: true` が必要 → `trustedCasks` に書く（`casks` には書かない）。
- VS Code 拡張は `vscodeExtensions` に書く。依存で自動インストールされる拡張も列挙しないと cleanup で消える。

### Claude Code

- **cask `claude-code`** で管理（nixpkgs-25.05 版は古く更新されないため）。
- 更新: `rebuild` または `brew upgrade --cask claude-code`。
- より新しいチャネルが欲しい場合は `claude-code@latest` に差し替え
  （両者は同じ `claude` を提供するので、先に `brew uninstall --cask claude-code`）。
- PATH: `environment.systemPath` に `/opt/homebrew/bin` を追加済み（Nix のパスより後ろ）。

### masApps

| アプリ | ID | 理由 |
|--------|----|------|
| WireGuard | 1451685025 | GUI 設定が必要 |
| Tailscale | 1475387142 | System Extension の権限が安定 |
| Slack | 803453959 | 通知の動作が安定 |
| Windows App | 1295203466 | 旧 Microsoft Remote Desktop |
| Microsoft Excel | 462058435 | |
| Brother iPrint&Scan | 1193539993 | |

> macSKK / XLD は mas インストール失敗のため cask で管理。
> webex は App Store 版もあるが、画面共有・マイク権限問題のため cask。zoom も cask で管理。

### 既存アプリを cask 管理へ移す場合

nix-darwin 25.05 の cask 指定には `--adopt` がないため、手動インストール済みのアプリをそのまま
`casks` に書くと rebuild が「既にアプリがある」で失敗する。先に `brew install --cask --adopt <cask>` で
取り込んでから `casks` に追記する（例: `media-center`）。

### Nix / Homebrew 管理外のアプリ（手動インストール）

| アプリ | 理由 |
|--------|------|
| Parallels Desktop 26 | cask は 27（有償のメジャー更新）。取り込むとライセンス外の版へ上がるおそれ |
| VMware Fusion 13 | cask 廃止（Broadcom アカウント経由の配布のみ） |
| MakeMKV 2.0 | cask（1.18.x）より新しい版を手動導入済み |
| e-Gov電子申請アプリケーション | cask なし。Intel 専用 |
| Pioneer DJ FwUpdateManager（`/Applications/Pioneer`） | rekordbox のインストーラが同梱で導入。単体の cask なし（rekordbox 本体は cask 管理） |
| Brother ドライバ（Push Scan Tool） | pkg インストーラ。Intel 専用の常駐プロセスあり（印刷は AirPrint のため不要） |

---

## デスクトップ

| 要素 | 管理 | 備考 |
|------|------|------|
| AeroSpace | 本体: cask / 設定: `programs.aerospace`（home/desktop.nix） | `start-at-login = true`。キー割当は下記 |
| sketchybar | `services.sketchybar`（modules/desktop.nix） | 左: ワークスペース 1〜9・前面アプリ / 右: 音量・電池・時計。`topmost=on` で、上端にマウスを寄せて出てくる標準メニューバーを覆い隠す |
| jankyborders | `services.jankyborders`（modules/desktop.nix） | round, width=5 |
| メニューバー | `_HIHideMenuBar = true` | sketchybar と重ならないよう標準メニューバーを自動非表示 |
| AeroSpace ギャップ | `gaps.outer.top`（home/desktop.nix） | 内蔵画面 `5`（ノッチのため macOS がメニューバー分を空けたまま）、外部モニター `37`（バー 32 + 5）。sketchybar を無効にするときは `5` に |
| Spaces | `spans-displays = true` | AeroSpace 推奨（ディスプレイごとの個別スペースをオフ）。反映にはログアウトが必要 |
| Dock | `autohide = true` / `mru-spaces = false` / `expose-group-apps = true` | 自動非表示・スペース自動並べ替えオフ・Mission Control でアプリごとにグループ化 |
| WindowManager | `GloballyEnabled` / `EnableStandardClickToShowDesktop` / `EnableTilingByEdgeDrag` / `EnableTopTilingByEdgeDrag` / `EnableTilingOptionAccelerator` すべて `false` | ステージマネージャ・壁紙クリックでデスクトップ表示・macOS 標準タイル機能をオフ（AeroSpace と競合するため） |

sketchybar を無効にする手順: `services.sketchybar.enable = false`、`_HIHideMenuBar = false`、
AeroSpace の `gaps.outer.top = 5`（単一値に戻す）。AeroSpace の `exec-on-workspace-change`（sketchybar への通知）は
`osConfig.services.sketchybar.enable` に連動して自動で有効・無効になる。

AeroSpace 導入時の手動作業: アクセシビリティ許可（プライバシーとセキュリティ > アクセシビリティ）、
`spans-displays` 反映のためのログアウト、標準の Space を各ディスプレイ 1 つに減らす。

AeroSpace キー: `alt-hjkl` フォーカス / `alt-shift-hjkl` 移動 / `alt-N`・`alt-shift-N` ワークスペース /
`alt-f` フルスクリーン / `alt-tab` ワークスペースを次のモニターへ。

---

## シェル

- zsh: autosuggestion / syntax highlighting。補完は home-manager の compinit と nix パッケージ同梱の補完を使用。
- `<C-r>`: atuin（fzf の割当を上書き）/ `<C-t>`: fzf ファイル / `Alt-c`: fzf ディレクトリ
- エイリアス: `rebuild`, `ll`, `lg`, `cat`(bat), `ls`(eza), `vlc-bd`
- `vlc-bd`: `open --env JAVA_HOME=…openjdk@17 -a VLC`（`open` は通常の環境変数を引き継がないため `--env`）

---

## macOS 制限・非対応ツール

| ツール | 状態 | 代替 |
|--------|------|------|
| `hping3` | nixpkgs-25.05-darwin 未対応 | OrbStack の Linux VM |
| `bettercap` | nixpkgs-25.05 で broken | OrbStack の Linux VM / proxyman |
| `angry-ip-scanner` / `owasp-zap` | 2026-09 以降 Gatekeeper で起動不可 | `network-radar` / `caido` |
| `aircrack-ng` | モニターモード非対応 | 解析のみ |
| Wireshark | キャプチャに ChmodBPF が必要 | 導入済み（`/Library/LaunchDaemons/org.wireshark.ChmodBPF.plist`） |

### Alfred
アプリ説明はほぼ全アプリが Spotlight メタデータを空にしているため表示不可。
Workflow「Brew Cask Finder」で `cask {キーワード}` 検索。

---

## 今後の課題

- nixpkgs / nix-darwin / home-manager 25.05 → 新しいリリースへ更新。
  その際 `programs.git.userName/userEmail` → `programs.git.settings.user.*`、
  `programs.git.delta` → `programs.delta` などの移行が必要。
