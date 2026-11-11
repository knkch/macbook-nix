{ lib, pkgs, ... }:
{
  # ── GnuPG（署名・暗号化。YubiKey の OpenPGP でも使う）─────────────────── #
  # 鍵や設定は ~/.gnupg（home-manager が gpg.conf などを書く。鍵そのものは管理しない）
  programs.gpg = {
    enable = true;
    # YubiKey は macOS の PC/SC 経由で使う。scdaemon 内蔵の CCID ドライバは macOS ではカードを
    # つかみ損ねたり、ykman や Yubico Authenticator と取り合いになったりするので切る
    scdaemonSettings.disable-ccid = true;
  };

  # ~/.gnupg は自分だけが読めるように（ほかの人も読めると gpg が「安全でない権限」と警告する）
  home.activation.gnupgPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "$HOME/.gnupg"
    run chmod 700 "$HOME/.gnupg"
  '';

  # gpg-agent: パスワード（PIN）は macOS の画面で尋ねる（pinentry-mac。キーチェーンに保存もできる）。
  # ターミナルの GPG_TTY などはシェルの設定に自動で入る
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry_mac;
    defaultCacheTtl = 600;  # 一度入れたパスワードを覚えておく秒数
    maxCacheTtl     = 7200;
  };
}
