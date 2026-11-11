{ config, lib, pkgs, ... }:
{
  # ── GnuPG（署名・暗号化・SSH。鍵の副鍵は YubiKey の中）───────────────── #
  # 鍵や設定は ~/.gnupg（home-manager が gpg.conf などを書く。鍵そのものは管理しない）。
  # 主鍵はオフラインのバックアップ USB だけにある。指紋は ~/fingerprint.txt
  programs.gpg = {
    enable = true;
    settings = {
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      charset = "utf-8";
      no-comments = true;
      no-emit-version = true;
      no-greeting = true;
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
      require-cross-certification = true;
      no-symkey-cache = true;
      use-agent = true;
      throw-keyids = true;
      # require-secmem と armor は普段の設定では外す（メールアプリなどとの相性問題を避ける）
    };
    # YubiKey は macOS の PC/SC 経由で使う。scdaemon 内蔵の CCID ドライバは macOS ではカードを
    # つかみ損ねたり、ykman や Yubico Authenticator と取り合いになったりするので切る
    scdaemonSettings.disable-ccid = true;
  };

  # ~/.gnupg は自分だけが読めるように（ほかの人も読めると gpg が「安全でない権限」と警告する）
  home.activation.gnupgPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "$HOME/.gnupg"
    run chmod 700 "$HOME/.gnupg"
  '';

  # gpg-agent: パスワード（PIN）は macOS の画面で尋ねる（pinentry-mac）。
  # SSH エージェントも兼ねる（YubiKey の認証副鍵で SSH）。zsh には SSH_AUTH_SOCK と GPG_TTY が自動で入る
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry_mac;
    defaultCacheTtl = 600;  # 一度入れたパスワードを覚えておく秒数
    maxCacheTtl     = 7200;
    defaultCacheTtlSsh = 600;
    maxCacheTtlSsh     = 7200;
  };

  # macOS は標準の ssh-agent の SSH_AUTH_SOCK をいつも入れているので、home-manager の
  # 「空のときだけ gpg-agent にする」設定が効かない。zsh では必ず gpg-agent の SSH を使う
  programs.zsh.initContent = ''
    export SSH_AUTH_SOCK="$(${config.programs.gpg.package}/bin/gpgconf --list-dirs agent-ssh-socket)"
  '';
}
