{ lib, pkgs, pkgsUnstable, ... }:
let
  # q で終了コード 9（ytplay が再生リストの残りもやめる）
  ytplayInput = pkgs.writeText "ytplay-input.conf" "q quit 9\n";
  ytplay = pkgs.writeShellApplication {
    name = "ytplay";
    runtimeInputs = [ pkgsUnstable.yt-dlp pkgs.mpv pkgs.coreutils ];
    runtimeEnv.YTPLAY_INPUT_CONF = "${ytplayInput}";
    text = builtins.readFile ./youtube/ytplay.sh;
  };
  # `youtube`: youtube-tui を開く。0.9.4 は保存済みのサムネイル（~/.local/share/youtube-tui/thumbnails）があると
  # 次に起動したときの検索が「Loading search results...」のまま止まる（2026-10-30 に確認。サムネイルを保存しない設定でも保存される）。
  # 起動のたびにサムネイルだけ消して回避する（再生履歴・保存した動画・登録チャンネルは別の場所なので残る）
  youtube = pkgs.writeShellScriptBin "youtube" ''
    rm -rf "''${HOME:?}/.local/share/youtube-tui/thumbnails"
    exec ${pkgsUnstable.youtube-tui}/bin/youtube-tui "$@"
  '';
in
{

  # ── YouTube: youtube-tui（画面）+ ytplay（再生）────────────────────────── #
  # youtube-tui は 0.9.4 を nixpkgs-unstable から（25.05 の 0.8.1 は検索結果の -1 を読めない。0.9 は Rust 1.88 以上が要る）。
  # 再生は ytplay（home/youtube/ytplay.sh）: mpv に YouTube の URL を直接渡すと多くの動画で 403 になるので、
  # yt-dlp の出力を mpv に流し込む。youtube-tui の「音声だけ」なども組み込みの mpv ではなく ytplay で再生する（home/youtube/commands.yml）。
  # 設定は rebuild のたびに普通のファイルとして書き込む（youtube-tui は起動のたびに設定を書き直すので、読み取り専用のリンクにすると検索が止まる）。
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
        youtube-downloader = "${pkgsUnstable.yt-dlp}/bin/yt-dlp";
        download-path = "~/Downloads/%(title)s-%(id)s.%(ext)s";
        terminal-emulator = "env"; # 保存は新しいターミナルを開かずに裏で実行（既定は Linux の konsole）
        video-player = "${ytplay}/bin/ytplay";
        browser = "open"; # 既定のブラウザで開く（既定は xdg-open）
      };
    });
  in ''
    dir="$HOME/.config/youtube-tui"
    mkdir -p "$dir"
    rm -f "$dir/main.yml" "$dir/commands.yml" # 以前のリンク（読み取り専用）が残っていれば消す
    install -m 644 ${main} "$dir/main.yml"
    install -m 644 ${./youtube/commands.yml} "$dir/commands.yml"
  '');

  home.packages = with pkgs; [
    # ── メディア ─────────────────────────────────────────────────────────── #
    ffmpeg       # 動画・音声変換（Blu-ray → MP3 等）
    mkvtoolnix   # MKV 操作
    mpv          # 動画・音声プレーヤー（`mpv <ファイル>`）
    pkgsUnstable.youtube-tui # YouTube の操作画面（上の youtubeTuiConfig）
    youtube                  # youtube-tui をサムネイルを消してから開く（上の let）
    ytplay                   # YouTube を yt-dlp で取りながら mpv で再生（`ytplay [--no-video] [--term] <URL>`）
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
