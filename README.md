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

## 主なツール

### デスクトップ

| ツール | 概要 |
|--------|------|
| AeroSpace | タイル型ウィンドウマネージャ（`alt-hjkl`） |
| Nixvim | Neovim（LSP / treesitter / telescope） |
| Starship | プロンプト（Nerd Font プリセット） |
| Ghostty | ターミナルエミュレータ |
| Sketchybar | カスタムステータスバー |
| jankyborders | ウィンドウ枠線 |
| macSKK | 日本語 IME（SKK-JISYO.L） |

### インフラ

| ツール | 概要 |
|--------|------|
| kubectl / helm / k9s | Kubernetes 操作 |
| terraform / ansible | IaC / 構成管理 |
| awscli2 / google-cloud-sdk | クラウド CLI |
| nmap / mtr / iperf3 | ネットワーク診断 |
| openlens | Kubernetes GUI |
| tableplus | データベース GUI |
| wireshark | パケットアナライザ |

### セキュリティ

| ツール | 概要 |
|--------|------|
| nuclei / nikto / gobuster | 脆弱性スキャン |
| burp-suite / caido / proxyman | Web プロキシ |
| metasploit | エクスプロイトフレームワーク |
| ghidra / radare2 | リバースエンジニアリング |
| hashcat / john | パスワード解析 |
| maltego | OSINT GUI |

### VPN

| ツール | 概要 |
|--------|------|
| WireGuard | VPN（GUI: App Store 版） |
| Tailscale | VPN（App Store 版） |

詳細は [CLAUDE.md](CLAUDE.md) を参照。
