{ config, lib, pkgs, ... }:
{
  # セキュリティ / ペネトレーション系ツール一式
  # 不要なときは `my.security.enable = false;` で丸ごと外せる
  options.my.security.enable = lib.mkEnableOption "セキュリティ診断ツール群" // { default = true; };

  config = lib.mkIf config.my.security.enable {
    home.packages = with pkgs; [
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
  };
}
