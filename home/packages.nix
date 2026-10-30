{ pkgs, ... }:
{
  home.shellAliases.youtube = "youtube-tui"; # 「youtube」で操作画面を開く

  # youtube-tui の設定（ほかの *.yml は初回起動時に既定のものが作られる）。
  # 検索などのデータは Invidious（YouTube の中継サーバー）から取る。公開サーバーの多くは外部からの検索を止めていて、
  # 2026-10-30 時点で検索が通ったのは yt.chocolatemoo53.com だけ。使えなくなったら https://api.invidious.io で
  # 「api: true」のサーバーを探して差し替える（確かめ方: curl 'https://<サーバー>/api/v1/search?q=test' が JSON を返すか）
  xdg.configFile."youtube-tui/main.yml".text = builtins.toJSON {
    mouse_support = true;
    invidious_instance = "https://yt.chocolatemoo53.com";
    write_config = "Try"; # このファイルは読み取り専用なので、書き換えに失敗しても続ける
    allow_unicode = true;
    message_bar_default = "All good :)";
    images = "HalfBlocks"; # cmux（Ghostty）は Sixel に対応していない
    refresh_after_modifying_search_filters = true;
    syncing = {
      download_images = true;
      sync_channel_info = true;
      sync_channel_cooldown_secs = 86400;
      sync_videos_cooldown_secs = 600;
    };
    limits = { watch_history = 50; search_history = 75; commands_history = 75; };
    image_index = 4;
    provider = "YouTube"; # 再生する URL は youtube.com（mpv が yt-dlp で取る）
    shell = "sh";
    legacy_input_handling = false;
    env = {
      save-path = "~/.local/share/youtube-tui/saved/";
      youtube-downloader = "yt-dlp";
      download-path = "~/Downloads/%(title)s-%(id)s.%(ext)s";
      terminal-emulator = "env"; # 保存は新しいターミナルを開かずに裏で実行（既定は Linux の konsole）
      video-player = "mpv";
      browser = "open"; # 既定のブラウザで開く（既定は firefox）
    };
  };

  home.packages = with pkgs; [
    # ── メディア ─────────────────────────────────────────────────────────── #
    ffmpeg       # 動画・音声変換（Blu-ray → MP3 等）
    mkvtoolnix   # MKV 操作
    mpv          # 動画・音声プレーヤー（`mpv <ファイル>`）
    youtube-tui  # YouTube の TUI。再生は mpv（`youtube`）
    yt-dlp       # mpv が YouTube などの動画を取るのに使う（youtube-tui の再生・保存にも必要）

    # ── CLI ユーティリティ ────────────────────────────────────────────────── #
    ripgrep      # 高速 grep
    # eza / bat / atuin / lazygit は programs.* で管理（home/shell.nix）
    fd           # find の代替
    jq           # JSON 整形・抽出
    yq-go        # YAML 整形・抽出
    gh           # GitHub CLI
    btop         # リソースモニタ
    just         # タスクランナー（Makefile 代替）

    # ── ネットワーク ──────────────────────────────────────────────────────── #
    nmap         # ネットワークスキャナ
    mtr          # traceroute + ping 統合
    ipcalc       # IP アドレス計算
    dog          # dig の代替（カラー出力）
    iperf3       # ネットワーク帯域測定
    netcat       # TCP/UDP デバッグ

    # ── コンテナ / Kubernetes ─────────────────────────────────────────────── #
    kubectl      # Kubernetes CLI
    kubernetes-helm  # Kubernetes パッケージマネージャ
    k9s          # Kubernetes TUI
    kubectx      # context / namespace 切り替え（kubens 同梱）
    stern        # 複数 Pod のログを同時 tail
    lazydocker   # Docker TUI
    dive         # Docker イメージのレイヤー解析

    # ── IaC / 構成管理 ────────────────────────────────────────────────────── #
    terraform    # IaC
    ansible      # 構成管理
    sops         # 暗号化シークレット管理（age / KMS 対応）
    age          # シンプルな暗号化ツール

    # ── クラウド CLI ──────────────────────────────────────────────────────── #
    awscli2           # AWS CLI v2
    google-cloud-sdk  # gcloud / gsutil / bq
    # セキュリティツールは home/security.nix
  ];
}
