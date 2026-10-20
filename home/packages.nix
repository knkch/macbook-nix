{ pkgs, ... }:
{
  home.packages = with pkgs; [
    skkDictionaries.l

    # ── メディア ─────────────────────────────────────────────────────────── #
    ffmpeg       # 動画・音声変換（Blu-ray → MP3 等）
    mkvtoolnix   # MKV 操作

    # ── CLI ユーティリティ ────────────────────────────────────────────────── #
    ripgrep      # 高速 grep
    eza          # ls の代替（アイコン・カラー付き）
    bat          # cat の代替（シンタックスハイライト）
    fd           # find の代替
    jq           # JSON 整形・抽出
    yq-go        # YAML 整形・抽出
    gh           # GitHub CLI
    atuin        # shell 履歴 fuzzy 検索・同期
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

    # ── セキュリティ：ネットワーク / パケット ─────────────────────────────── #
    masscan      # 高速ポートスキャナ
    ngrep        # ネットワーク grep
    tcpdump      # パケットキャプチャ
    # hping3 は nixpkgs-25.05-darwin に未対応（Linux のみ）

    # ── セキュリティ：脆弱性スキャン ──────────────────────────────────────── #
    nuclei       # テンプレートベース脆弱性スキャナ
    nikto        # Web サーバー脆弱性スキャナ
    gobuster     # ディレクトリ / DNS / vhost ブルートフォース
    ffuf         # Web ファジング
    sqlmap       # SQL インジェクション検出

    # ── セキュリティ：コンテナ / IaC ──────────────────────────────────────── #
    trivy        # コンテナ・IaC・SBOM 脆弱性スキャナ
    grype        # コンテナイメージ脆弱性スキャナ
    syft         # SBOM 生成
    checkov      # IaC セキュリティスキャン

    # ── セキュリティ：SSL / シークレット / 監査 ───────────────────────────── #
    sslscan      # SSL/TLS プロトコル・暗号スイート検査
    testssl      # SSL/TLS 設定の詳細検査
    gitleaks     # Git リポジトリのシークレット検出
    trufflehog   # Git 履歴の深掘りシークレット探索
    lynis        # システムセキュリティ監査

    # ── セキュリティ：エクスプロイト / ペネトレーション ──────────────────── #
    metasploit   # エクスプロイトフレームワーク（初回: msfdb init が必要）

    # ── セキュリティ：パスワード解析 ──────────────────────────────────────── #
    hashcat      # GPU ベース高速パスワードクラック
    john         # CPU ベースパスワードクラック（John the Ripper）

    # ── セキュリティ：リバースエンジニアリング ────────────────────────────── #
    ghidra       # NSA 製リバースエンジニアリングスイート
    radare2      # CLI リバースエンジニアリングフレームワーク
    binwalk      # ファームウェア / バイナリ解析

    # ── セキュリティ：フォレンジクス ──────────────────────────────────────── #
    volatility3  # メモリフォレンジクス
    exiftool     # ファイルメタデータ抽出・編集

    # ── セキュリティ：OSINT ────────────────────────────────────────────────── #
    theharvester # メール / ドメイン / ホスト収集
    subfinder    # サブドメイン列挙
    amass        # 攻撃対象領域マッピング

    # ── セキュリティ：ネットワーク攻撃 ───────────────────────────────────── #
    # bettercap は nixpkgs-25.05 で broken のため除外（OrbStack の Linux VM で使用推奨）
    aircrack-ng  # WiFi セキュリティ監査（macOS はモニターモード制限あり）
    wpscan       # WordPress 脆弱性スキャナ
  ];
}
