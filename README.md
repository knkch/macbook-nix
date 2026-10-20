# KokinoMacBook-Pro — nix-darwin Config

nix-darwin + home-manager による macOS 環境の宣言的管理。

- **ホスト**: KokinoMacBook-Pro
- **アーキテクチャ**: aarch64-darwin (Apple Silicon)
- **チャンネル**: nixpkgs-25.05-darwin (stable)

## クイックスタート

```bash
# 設定を適用
darwin-rebuild switch --flake ~/.config/nix-darwin

# エイリアス（適用後）
rebuild
```

## ファイル構成

```
.
├── flake.nix              # flake inputs / outputs エントリポイント
├── flake.lock             # 依存関係のロック
├── CLAUDE.md              # 詳細ドキュメント
├── modules/
│   ├── system.nix         # nix 設定・システムパッケージ・macOS defaults・GC
│   └── homebrew.nix       # Homebrew casks / brews / masApps
├── home/
│   ├── default.nix        # ユーザー情報・dotfiles・imports
│   ├── packages.nix       # home.packages（CLI / インフラ / セキュリティ）
│   ├── shell.nix          # zsh・starship・zoxide・fzf・lazygit・atuin・direnv
│   ├── git.nix            # git + delta
│   ├── nixvim.nix         # Neovim（nixvim）全設定
│   ├── desktop.nix        # AeroSpace・Ghostty・jankyborders・sketchybar
│   └── vscode.nix         # VSCode 拡張
└── config/
    └── sketchybar/
        └── sketchybarrc   # Sketchybar バー設定スクリプト
```

## 管理しているもの

| 種別 | 管理方法 |
|------|----------|
| システムパッケージ | `environment.systemPackages` (modules/system.nix) |
| ユーザー開発ツール | `home.packages` (home/packages.nix) |
| GUI アプリ（App Store 外） | `homebrew.casks` (modules/homebrew.nix) |
| GUI アプリ（App Store） | `homebrew.masApps` (modules/homebrew.nix) |
| Shell・プロンプト | `programs.*` (home/shell.nix) |
| Neovim | nixvim (home/nixvim.nix) |
| デスクトップ環境 | xdg.configFile / launchd (home/desktop.nix) |
| VSCode 拡張 | `profiles.default.extensions` (home/vscode.nix) |
| VSCode 設定 (`settings.json`) | Nix 管理外・VSCode が直接書き込み |

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
