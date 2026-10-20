# nix-darwin Configuration — KokinoMacBook-Pro

nix-darwin + home-manager による macOS 環境の宣言的管理。  
ホスト: `KokinoMacBook-Pro` / アーキテクチャ: `aarch64-darwin`

## 適用コマンド

```bash
darwin-rebuild switch --flake ~/.config/nix-darwin
# または
rebuild   # zsh エイリアス
```

---

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `flake.nix` | flake inputs・outputs のエントリポイントのみ |
| `modules/system.nix` | nix 設定・システムパッケージ・macOS defaults・GC・Activation |
| `modules/homebrew.nix` | Homebrew casks / brews / masApps |
| `home/default.nix` | ユーザー情報・dotfiles・imports |
| `home/packages.nix` | home.packages（CLI / インフラ / セキュリティツール群） |
| `home/shell.nix` | zsh・starship・zoxide・fzf・lazygit・atuin・direnv |
| `home/git.nix` | git + delta |
| `home/nixvim.nix` | Neovim（nixvim）全設定 |
| `home/desktop.nix` | AeroSpace・Ghostty・jankyborders・sketchybar |
| `home/vscode.nix` | VSCode 拡張 |
| `config/sketchybar/sketchybarrc` | Sketchybar バー設定スクリプト |
| `flake.lock` | input のロック済みリビジョン |

### 配置の原則

| 種別 | 置き場所 |
|------|----------|
| システム全体・ネットワークツール | `environment.systemPackages` (modules/system.nix) |
| ユーザー開発ツール | `home.packages` / `programs.*` (home/packages.nix 等) |
| GUI アプリ（App Store 外） | `homebrew.casks` (modules/homebrew.nix) |
| GUI アプリ（App Store）| `homebrew.masApps` (modules/homebrew.nix) |
| dotfiles (任意パス) | `home.file.*` (home/default.nix) |
| dotfiles (`~/.config/`) | `xdg.configFile.*` (home/desktop.nix 等) |
| Launchd agents | `launchd.agents.*` (home/desktop.nix) |

---

## アカウント情報

| 項目 | 値 | 定義場所 |
|------|----|----------|
| システムユーザー | `konkichi` | `flake.nix` → `system.primaryUser` |
| home-manager ユーザー | `konkichi` / `/Users/konkichi` | `home.nix` → `home.username` / `home.homeDirectory` |
| Git name | `knkch` | `home.nix` → `programs.git.userName` |
| Git email | `255763411+knkch@users.noreply.github.com` | `home.nix` → `programs.git.userEmail` |

> `system.primaryUser` と `home.username` の重複は nix-darwin の仕様上必要。  
> VSCode のアカウント（GitHub 等）は GUI でサインイン。

---

## System Packages (flake.nix)

| カテゴリ | パッケージ |
|----------|-----------|
| Network | `wireguard-tools`, `wireguard-go` |
| System utils | `fastfetch`, `htop`, `yazi`, `picocom`, `minicom`, `xxd` |
| Desktop | `jankyborders`, `sketchybar`, `claude-code`, `orbstack` |

> WireGuard の GUI は App Store 版（`masApps` 管理）を使用。  
> `wireguard-tools` / `wireguard-go` は CLI 用途。  
> `jankyborders` / `sketchybar` は `home.packages` には置かない（`systemPackages` のみ）。

---

## Homebrew (flake.nix)

### Casks — App Store 外・ドライバ・カスタム tap

| カテゴリ | アプリ | cask 必須の理由 |
|----------|--------|----------------|
| Browser | brave-browser, google-chrome | App Store 版なし |
| Input / IME | karabiner-elements | カーネル拡張、cask 必須 |
| Input / IME | macskk | App Store ID 不明のため cask で管理 |
| Fonts | font-hack-nerd-font | cask のみ |
| Terminal / Dev | tabby, cmux, visual-studio-code, antigravity | App Store 版なし |
| Terminal / Dev | silicon-labs-vcp-driver | USB ドライバ、cask 必須 |
| Communication | claude, discord, webex | App Store 版なし / 権限問題のため cask 推奨 |
| Gaming | steam, xiv-on-mac, chiaki-ng, rekordbox, prismlauncher | App Store 版なし |
| Remote / VPN | omnissa-horizon-client | エンタープライズ配布のみ |
| Utility | alfred, xld | App Store 版なし / ID 不明のため cask で管理 |
| Infrastructure | wireshark, angry-ip-scanner, openlens, tableplus, bruno, dash | インフラ向け GUI ツール群 |
| Security | burp-suite, maltego, temurin@11 | Web セキュリティ診断・OSINT GUI |

> **webex** は App Store 版あり（ID: 1085114709）だが、画面共有・マイク等の権限問題のため cask 推奨。

### masApps — App Store 版が推奨なもの

| アプリ | App Store ID | mas 推奨の理由 |
|--------|-------------|----------------|
| WireGuard | 1451685025 | GUI 設定が必要 |
| Tailscale | 1475387142 | System Extension の権限が安定 |
| Slack | 803453959 | 通知の動作が安定 |
| Microsoft Remote Desktop | 手動 | mas 非対応のため App Store から直接インストール |

> `mas` CLI は `homebrew.brews` で管理。  
> macSKK (1456805826) / XLD (425215670) は mas インストール失敗のため cask に戻した。

---

## home.nix — 主要設定

### Shell (Zsh)
- autosuggestion / syntax highlighting 有効
- starship プロンプト (`nerd-font-symbols` プリセット相当)
- エイリアス: `rebuild`, `ll`, `lg`（lazygit）
- zoxide: `z <dir>` で移動（zsh 統合済み）
- fzf: `<C-r>` 履歴 / `<C-t>` ファイル / `Alt-c` ディレクトリ（zsh 統合済み）
- atuin: `<C-r>` 履歴 fuzzy 検索・同期
- direnv + nix-direnv: `.envrc` に `use flake` で自動 shell 切り替え
- lazygit: `lg` で起動
- インフラ: nmap / mtr / ipcalc / dog / iperf3 / netcat
- K8s: kubectl / helm / k9s / kubectx / stern / lazydocker / dive
- IaC: terraform / ansible / sops / age
- Cloud: awscli2 / google-cloud-sdk

### Nixvim (Neovim)

| カテゴリ | プラグイン |
|----------|-----------|
| Colorscheme | tokyonight |
| LSP | gopls, pyright, nil_ls, yamlls, clangd, ts_ls, rust_analyzer |
| LSP keymaps | `gd` def / `gD` decl / `K` hover / `gi` impl / `gr` refs / `<leader>rn` rename / `<leader>ca` action / `<leader>j/k` diag |
| Completion | nvim-cmp, luasnip, cmp-nvim-lsp, cmp-buffer, cmp-path |
| Fuzzy finder | telescope (`<leader>ff/fg/fb/fh`) |
| Syntax | treesitter |
| UI | lualine, gitsigns, nvim-tree, toggleterm (`<C-t>`), indent-blankline |
| Edit assist | nvim-autopairs, comment, web-devicons |

### AeroSpace (Window Manager)
- `programs.aerospace` DSL は home-manager 25.05 に未対応 → `xdg.configFile."aerospace/aerospace.toml"` で管理
- vim スタイル `alt-hjkl` でフォーカス移動
- `alt-shift-hjkl` でウィンドウ移動
- ワークスペース 1〜9: `alt-N` / `alt-shift-N`
- `alt-tab`: ワークスペースをモニター間移動

### VSCode (home-manager 管理)

| カテゴリ | 拡張 |
|----------|------|
| Remote | remote-ssh, remote-containers |
| Python | ms-python.python, debugpy |
| Go | golang.go |
| Git | gitlens, git-graph |
| Language pack | vscode-language-pack-ja |
| Containerlab | srl-labs.vscode-containerlab (Marketplace) |

> `ms-python.pylance` は proprietary のため nixpkgs 非対応 → 削除済み（python 拡張に言語サーバー機能が内包）。  
> `userSettings` は home-manager 管理外。VSCode が `settings.json` に直接書き込めるようにするため。  
> `containerlab.editor.customNodes` / `remote.SSH.defaultExtensions` は VSCode GUI または `settings.json` で手動設定。  
> 拡張は `profiles.default.extensions` で管理（home-manager 25.05 での正式オプション名）。

### Launchd Agents

| エージェント | 状態 | 備考 |
|-------------|------|------|
| jankyborders | 有効 | round, width=5, active=pink / inactive=blue |

> sketchybar / cmux は launchd 管理外。sketchybar は `brew services start sketchybar`、cmux は手動起動。

### Dotfiles

| パス | 内容 |
|------|------|
| `~/.config/ghostty/config` | フォント: Hack Nerd Font / 透過 0.85（xdg.configFile 管理） |
| `~/Library/.../macSKK/Settings.json` | SKK-JISYO.L 辞書パス（`pkgs.skkDictionaries.l` のストアパスを参照） |
| `~/Library/.../Code/User/locale.json` | VSCode 表示言語: ja |

---

## macOS 制限・非対応ツール

### nixpkgs で除外したパッケージ

| パッケージ | 理由 | 代替 |
|-----------|------|------|
| `hping3` | nixpkgs-25.05-darwin 未対応（Linux のみ） | OrbStack の Linux VM で使用 |
| `bettercap` | nixpkgs-25.05 で broken マーク | OrbStack の Linux VM で使用 |

### Homebrew Cask で除外したアプリ

| アプリ | 理由 | 代替 |
|--------|------|------|
| `angry-ip-scanner` | 2026-09 以降 Gatekeeper 無効化（未署名） | `network-radar` cask |
| `owasp-zap` | 2026-09 以降 Gatekeeper 無効化（未署名） | `caido` cask |

### macOS 動作制限があるツール

| ツール | 制限内容 | 備考 |
|--------|----------|------|
| `aircrack-ng` | macOS はモニターモード非対応 | 解析のみ可、パケットキャプチャ不可 |
| `wireshark` | パケットキャプチャに `ChmodBPF` が必要 | `wireshark-chmodbpf` cask で解決 |
| WireGuard | CLI ツールは動作するが GUI は System Extension 必須 | App Store 版（masApps）を使用 |

### Alfred の制限

| 機能 | 制限 | 理由 |
|------|------|------|
| アプリ検索での説明表示 | 標準では不可 | Alfred は Spotlight インデックスを使用、ほぼ全アプリが `kMDItemDescription` を空にしている |
| Spotlight メタデータへの説明追加 | 非推奨 | アプリ更新のたびにリセットされる |

> **workaround**: Alfred Workflow「Brew Cask Finder」を導入済み。  
> `cask {キーワード}` で Homebrew カタログを説明付きで検索できる。  
> Enter で未インストールなら `brew install --cask` コマンドをクリップボードにコピー。
