{ config, lib, pkgs, user, ... }:
let
  cfg = config.homebrew;

  # サードパーティ tap の cask（Homebrew 7 以降は trusted 指定が必要）
  trustedCasks = [
    "manaflow-ai/cmux/cmux"
    "streetpea/streetpea/chiaki-ng"
    "nikitabobko/tap/aerospace"
  ];

  # VS Code 拡張（Brewfile の `vscode` 行で管理 → 常に Marketplace の最新版）
  # 依存で自動インストールされる拡張も列挙しておかないと cleanup で消える
  vscodeExtensions = [
    # Remote
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-containers"
    "ms-azuretools.vscode-containers"
    # GitHub Repositories
    "github.remotehub"
    "ms-vscode.remote-repositories"
    "ms-vscode.azure-repos"
    # Language pack
    "ms-ceintl.vscode-language-pack-ja"
    # Python
    "ms-python.python"
    "ms-python.vscode-pylance"   # nixpkgs では unfree で使えなかったが Marketplace なら可
    "ms-python.debugpy"
    # Go
    "golang.go"
    # Git
    "eamodio.gitlens"
    "mhutchie.git-graph"
    # Network lab / Diagram
    "srl-labs.vscode-containerlab"
    "hediet.vscode-drawio"
  ];

  brewfile = pkgs.writeText "Brewfile" cfg.brewfile;
in
{
  homebrew = {
    enable = true;

    taps = [
      "manaflow-ai/cmux"
      "streetpea/streetpea"
      "nikitabobko/tap"
    ];

    casks = [
      # Browser
      "brave-browser"
      "google-chrome"

      # Input / IME
      "karabiner-elements"
      "macskk"

      # Fonts
      "font-hack-nerd-font"

      # Terminal / Dev
      "claude-code"             # nixpkgs 版は更新が遅いため cask で最新を追従
      "visual-studio-code"      # 拡張は下の vscodeExtensions で管理
      "orbstack"                # Docker / Linux VM（ヘルパー・自動更新のため cask）
      "tabby"
      "antigravity"
      "silicon-labs-vcp-driver"

      # Communication
      "claude"
      "discord"
      "webex"                   # App Store 版は画面共有・マイク権限が不安定
      "zoom"

      # Gaming
      "steam"
      "xiv-on-mac"
      "prismlauncher"

      # Remote / VPN
      "omnissa-horizon-client"

      # Utility
      "alfred"
      "xld"

      # Media / Music / Blu-ray
      "vlc"
      "rekordbox"
      "media-center"            # JRiver Media Center（auto_updates のため rebuild ではメジャー更新されない）

      # ── Infrastructure ──────────────────────────────────────────────────── #
      "wireshark-app"   # パケットアナライザ（ChmodBPF は導入済み）
      "network-radar"   # ネットワークスキャナ GUI（angry-ip-scanner 代替）
      "openlens"        # Kubernetes GUI IDE
      "tableplus"       # マルチ DB クライアント
      "bruno"           # REST / GraphQL クライアント（OSS）
      "dash"            # オフライン API ドキュメントブラウザ

      # ── Security ────────────────────────────────────────────────────────── #
      "burp-suite"      # Web セキュリティプロキシ
      "caido"           # モダン Web セキュリティプロキシ GUI（owasp-zap 代替）
      "proxyman"        # macOS ネイティブ HTTP デバッグプロキシ
      "maltego"         # OSINT / 脅威インテリジェンス GUI
      "temurin@11"      # Maltego が要求する Java 11
    ];

    brews = [
      "mas"
      # Blu-ray: libaacs/libbluray は VLC が参照するため brew で管理
      "libaacs"
      "libbluray"
      "openjdk@17"   # VLC の BD-J メニュー用（最新 JDK はクラッシュ）
      "ical-buddy"   # sketchybar のカレンダー画像（祝日・予定の件数）
    ];

    masApps = {
      "WireGuard"           = 1451685025; # GUI 設定が必要
      "Tailscale"           = 1475387142; # System Extension の権限が安定
      "Slack"               = 803453959;  # 通知の動作が安定
      "Windows App"         = 1295203466; # 旧 Microsoft Remote Desktop
      "Microsoft Excel"     = 462058435;
      "Brother iPrint&Scan" = 1193539993;
    };

    extraConfig = lib.concatLines (
      map (c: ''cask "${c}", trusted: true'') trustedCasks
      ++ map (e: ''vscode "${e}"'') vscodeExtensions
    );

    onActivation = {
      autoUpdate = true;  # Homebrew 本体・定義を更新
      upgrade    = true;  # claude-code 等を rebuild 時に最新へ
    };
  };

  # Homebrew 7 で `brew bundle --cleanup` が廃止され onActivation.cleanup が使えないため、
  # `brew bundle cleanup` を直接実行して Brewfile にないものを削除する（zap はしない）
  system.activationScripts.homebrew.text = lib.mkAfter ''
    echo >&2 "Homebrew bundle cleanup..."
    if [ -f "${cfg.brewPrefix}/brew" ]; then
      PATH="${cfg.brewPrefix}:$PATH" \
      sudo --user=${user} --set-home \
        brew bundle cleanup --force --file='${brewfile}' || true
    fi
  '';
}
