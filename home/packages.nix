{ lib, pkgs, pkgsUnstable, ... }:
{
  home.shellAliases.youtube = "pipe-viewer"; # 「youtube」で検索・再生（番号を選ぶと再生。`youtube -n …` で音声だけ）
  home.shellAliases.youtube-term = "pipe-viewer --player=ytterm"; # 動画をターミナルの中に映す（cmux / Ghostty の Kitty 方式）

  # YouTube: 検索は pipe-viewer（Invidious などの中継サーバーを使わず YouTube から直接）、再生は ytplay。
  # mpv に YouTube の URL を渡す普通の再生（mpv が yt-dlp から受け取ったリンクを直接読む）は、多くの動画で
  # 403 Forbidden になる（2026-10 時点）。yt-dlp 自身のダウンロードは通るので、yt-dlp の出力をそのまま mpv に流す。
  # 標準入力ではなくプロセス置換で渡すので、mpv をターミナルのキー（space・← →・q など）で操作できる。
  # youtube-tui は 0.8.1 が検索結果の -1 を読めず、0.9 は設定ファイルの扱いが不安定だったのでやめた（CLAUDE.md）
  # 設定 ~/.config/pipe-viewer/pipe-viewer.conf は rebuild のたびに書き込む（pipe-viewer は足りない項目を補って
  # 自分で書き直すので、読み取り専用のリンクにはしない）。
  home.activation.pipeViewerConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (let
    ytplay = pkgs.writeShellApplication {
      name = "ytplay";
      runtimeInputs = [ pkgsUnstable.yt-dlp pkgs.mpv ];
      text = ''
        # ytplay [--term] [mpv のオプション…] <YouTube の URL>: yt-dlp で取りながら mpv で再生
        #   --no-video: 音声だけ取る / --term: ターミナルの中に映す（Kitty 方式。細かい画質は活きないので 480p）
        url="" fmt="bv*[height<=1080]+ba/b" args=() term=""
        for a in "$@"; do
          case "$a" in
            http*) url="$a" ;;
            --no-video) fmt="ba/b"; args+=("$a") ;;
            --term) term=1 ;;
            *) args+=("$a") ;;
          esac
        done
        [ -n "$url" ] || { echo "使い方: ytplay [--term] [mpv のオプション…] <URL>" >&2; exit 2; }
        if [ -n "$term" ] && [ "$fmt" != "ba/b" ]; then
          fmt="bv*[height<=480]+ba/b"
          args=(--vo=kitty --really-quiet "''${args[@]}")
        fi
        # AV1 はハードウェアで再生できない Mac があるので、h264 → vp9 を優先する
        mpv "''${args[@]}" <(yt-dlp -q --no-warnings -S "vcodec:h264,vcodec:vp9" -f "$fmt" -o - "$url")
      '';
    };
    conf = pkgs.writeText "pipe-viewer.conf" ''
      use utf8;

      our $CONFIG = {
        video_player_selected => "ytplay",
        video_players => {
          ytplay => {
            cmd     => "${ytplay}/bin/ytplay",
            arg     => "--force-media-title=*TITLE* *URL*",
            fs      => "--fullscreen",
            novideo => "--no-video",
          },
          ytterm => {
            cmd     => "${ytplay}/bin/ytplay",
            arg     => "--term --force-media-title=*TITLE* *URL*",
            novideo => "--no-video",
          },
        },
        ytdl     => 1,
        ytdl_cmd => "${pkgsUnstable.yt-dlp}/bin/yt-dlp",
      };
    '';
  in ''
    dir="$HOME/.config/pipe-viewer"
    mkdir -p "$dir"
    install -m 644 ${conf} "$dir/pipe-viewer.conf"
  '');

  home.packages = with pkgs; [
    # ── メディア ─────────────────────────────────────────────────────────── #
    ffmpeg       # 動画・音声変換（Blu-ray → MP3 等）
    mkvtoolnix   # MKV 操作
    mpv          # 動画・音声プレーヤー（`mpv <ファイル>`）
    pipe-viewer  # YouTube の検索・再生（`youtube`。上の pipeViewerConfig）
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
