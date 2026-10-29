{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── メディア ─────────────────────────────────────────────────────────── #
    ffmpeg       # 動画・音声変換（Blu-ray → MP3 等）
    mkvtoolnix   # MKV 操作
    mpv          # 動画・音声プレーヤー（`mpv <ファイル>`）

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
