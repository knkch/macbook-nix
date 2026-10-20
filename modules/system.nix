{ config, pkgs, self, user, ... }:
{
  # ── Nix ─────────────────────────────────────────────────────────────────── #
  nixpkgs.hostPlatform               = "aarch64-darwin";
  nixpkgs.config.allowUnfree         = true;
  nix.settings.experimental-features = "nix-command flakes";

  nix.gc = {
    automatic = true;
    interval  = { Hour = 3; Minute = 0; Weekday = 0; }; # 毎週日曜 3:00
    options   = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # ── System / User ───────────────────────────────────────────────────────── #
  system.stateVersion          = 6;
  system.primaryUser           = user;
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # home-manager がホームディレクトリを解決できるよう明示（mkForce 不要になる）
  users.users.${user}.home = "/Users/${user}";

  programs.zsh.enable = true;

  # Homebrew の bin を PATH に追加（cask の claude / code 等を使うため）
  # Nix のパスより後ろに入るので、同名コマンドは Nix 版が優先される
  environment.systemPath = [
    "${config.homebrew.brewPrefix}"
    "/opt/homebrew/sbin"
  ];

  # ── System Packages ─────────────────────────────────────────────────────── #
  # システム全体・ネットワーク寄りの CLI のみ
  # ユーザー開発ツールは home/packages.nix、GUI アプリは modules/homebrew.nix、
  # 常駐サービス（sketchybar / jankyborders）は modules/desktop.nix
  environment.systemPackages = with pkgs; [
    # Network
    wireguard-tools
    wireguard-go
    # System utils
    fastfetch
    htop
    yazi
    picocom
    minicom
    xxd
  ];

  # ── macOS Defaults ───────────────────────────────────────────────────────── #
  system.defaults = {
    # AeroSpace 推奨: 「ディスプレイごとに個別の操作スペース」をオフ
    spaces.spans-displays = true;
    dock.mru-spaces       = false;
    # sketchybar と重ならないようメニューバーを自動的に隠す
    NSGlobalDomain._HIHideMenuBar = true;
    CustomUserPreferences = {
      "com.apple.WindowManager".GloballyEnabled     = false;
      ".GlobalPreferences".NSQuitAlwaysKeepsWindows = false;
      "com.apple.loginwindow".TALLogoutSavesState   = false;
    };
  };

  # ── Activation Scripts ───────────────────────────────────────────────────── #
  system.activationScripts.extraActivation.text = ''
    if ! /usr/bin/pgrep -q oahd; then
      /usr/sbin/softwareupdate --install-rosetta --agree-to-license
    fi
  '';
}
