{ lib, pkgs, pkgsUnstable, ... }:
{
  home.shellAliases.youtube = "youtube-tui"; # 「youtube」で YouTube の操作画面を開く

  # ── mpv（動画・音声プレーヤー。`mpv <ファイルや URL>`）──────────────────── #
  # YouTube の再生のための設定（2026-10-30 時点）:
  # - nixpkgs の mpv は同梱の古い yt-dlp を使うので、新しい yt-dlp（unstable）を使わせる（ytdl_hook-ytdl_path）
  # - 普通の形式は mpv が読むと 403 Forbidden になる。細かく区切って配信する HLS（m3u8）形式なら読めるので、それを選ぶ
  #   （1080p まで。HLS がない動画は普通の形式）。Mac で負担の少ない h264 を優先する
  programs.mpv = {
    enable = true;
    config = {
      script-opts = "ytdl_hook-ytdl_path=${pkgsUnstable.yt-dlp}/bin/yt-dlp";
      ytdl-format = "bv*[protocol^=m3u8][height<=1080]+ba[protocol^=m3u8]/b[protocol^=m3u8]/b";
      ytdl-raw-options-append = "format-sort=vcodec:h264";
    };
  };

  # ── YouTube: youtube-tui ─────────────────────────────────────────────── #
  # youtube-tui は 0.9.4 を nixpkgs-unstable から（25.05 の 0.8.1 は検索結果の -1 を読めない。0.9 は Rust 1.88 以上が要る）。
  # 標準の機能のまま使い、設定 main.yml だけを Mac 向けにする。rebuild のたびに普通のファイルとして書き込む
  # （youtube-tui は起動のたびに設定を書き直すので、読み取り専用のリンクにすると検索が止まる）。ほかの *.yml は youtube-tui が作る。
  # 検索は YouTube から直接（RustyPipe）。Invidious（中継サーバー）は動画の詳細などに使う。公開サーバーの多くは外部からの利用を
  # 止めていて、2026-10-30 時点で通ったのは yt.chocolatemoo53.com。使えなくなったら https://api.invidious.io で探して差し替える
  home.activation.youtubeTuiConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (let
    main = pkgs.writeText "youtube-tui-main.yml" (builtins.toJSON {
      mouse_support = true;
      invidious_instance = "https://yt.chocolatemoo53.com";
      write_config = "Try";
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
      textbar_scroll_behaviour = "History";
      image_index = 4;
      provider = "YouTube";
      search_provider = "RustyPipe"; # 検索は Invidious を通さず YouTube から直接
      shell = "sh";
      legacy_input_handling = false;
      env = {
        save-path = "~/.local/share/youtube-tui/saved/";
        youtube-downloader = "yt-dlp";
        download-path = "~/Downloads/%(title)s-%(id)s.%(ext)s";
        terminal-emulator = "env"; # 保存は新しいターミナルを開かずに裏で実行（既定は Linux の konsole）
        video-player = "mpv";
        browser = "open"; # 既定のブラウザで開く（既定は xdg-open）
      };
    });
  in ''
    dir="$HOME/.config/youtube-tui"
    mkdir -p "$dir"
    rm -f "$dir/main.yml" # 以前のリンク（読み取り専用）が残っていれば消す
    install -m 644 ${main} "$dir/main.yml"
  '');

  home.packages = with pkgs; [
    # ── メディア ─────────────────────────────────────────────────────────── #
    ffmpeg       # 動画・音声変換（Blu-ray → MP3 等）
    mkvtoolnix   # MKV 操作
    pkgsUnstable.youtube-tui # YouTube の操作画面（`youtube`。上の youtubeTuiConfig）
    # yt-dlp は YouTube 側の変更に追いつくため頻繁に更新されるので、新しい unstable の版を使う（25.05 の版では再生できない動画が多い）
    pkgsUnstable.yt-dlp

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
