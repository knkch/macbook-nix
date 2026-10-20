{ ... }:
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

      # Window Manager
      "nikitabobko/tap/aerospace"  # タイル型ウィンドウマネージャ

      # Terminal / Dev
      "tabby"
      "cmux"
      "visual-studio-code"
      "antigravity"
      "silicon-labs-vcp-driver"
      "claude-code"
      
      # Communication
      "claude"
      "discord"
      "webex"

      # Gaming
      "steam"
      "xiv-on-mac"
      "chiaki-ng"
      "rekordbox"
      "prismlauncher"

      # Remote / VPN
      "omnissa-horizon-client"

      # Utility
      "alfred"
      "xld"

      # Blu-ray
      "vlc"

      # ── Infrastructure ──────────────────────────────────────────────────── #

      # Network
      "wireshark"       # パケットアナライザ
      "network-radar"   # ネットワークスキャナ GUI（angry-ip-scanner 代替）

      # Kubernetes
      "openlens"      # Kubernetes GUI IDE

      # Database
      "tableplus"     # マルチ DB クライアント

      # API
      "bruno"         # REST / GraphQL クライアント（OSS）

      # Documentation
      "dash"          # オフライン API ドキュメントブラウザ

      # ── Security ────────────────────────────────────────────────────────── #
      "burp-suite"    # Web セキュリティプロキシ
      "caido"         # モダン Web セキュリティプロキシ GUI（owasp-zap 代替）
      "proxyman"      # macOS ネイティブ HTTP デバッグプロキシ（bettercap HTTP 傍受の代替）
      "maltego"       # OSINT / 脅威インテリジェンス GUI
      "temurin@11"    # Maltego が要求する Java 11
    ];

    # 公式 Homebrew tap 外 / サードパーティ tap は trusted: true が必要
    extraConfig = ''
      cask "manaflow-ai/cmux/cmux", trusted: true
      cask "streetpea/streetpea/chiaki-ng", trusted: true
      cask "nikitabobko/tap/aerospace", trusted: true
    '';

    brews = [
      "mas"
      # Blu-ray: libaacs/libbluray は VLC cask が参照するため brew で管理
      "libaacs"
      "libbluray"
      "openjdk@17"   # 最新 JDK は VLC がクラッシュするため 17 固定
    ];

    masApps = {
      "WireGuard" = 1451685025; # GUI 設定が必要
      "Tailscale" = 1475387142; # System Extension の権限が安定
      "Slack"     = 803453959;  # 通知の動作が安定
      # LanScan は日本 App Store 非対応のため除外（network-radar cask で代替）
      # Microsoft Remote Desktop (1295203466) は mas 非対応のため App Store から手動インストール
    };

    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
# cleanup オプションは現行 Homebrew で --cleanup フラグが廃止されたため使用不可
  };
}
