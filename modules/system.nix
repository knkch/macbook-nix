{ pkgs, self, ... }:
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

  # ── System ──────────────────────────────────────────────────────────────── #
  system.stateVersion          = 6;
  system.primaryUser           = "konkichi";
  system.configurationRevision = self.rev or self.dirtyRev or null;

  programs.zsh.enable = true;

  # ── System Packages ─────────────────────────────────────────────────────── #
  # システム全体・ネットワーク寄りのツールのみ
  # ユーザー開発ツールは home/packages.nix、GUI アプリは modules/homebrew.nix へ
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
    # Desktop
    jankyborders
    sketchybar
    orbstack
  ];

  # ── macOS Defaults ───────────────────────────────────────────────────────── #
  system.defaults = {
    spaces.spans-displays = false;
    dock.mru-spaces       = false;
    CustomUserPreferences = {
      "com.apple.WindowManager".GloballyEnabled     = false;
      ".GlobalPreferences".NSQuitAlwaysKeepsWindows = false;
      "com.apple.loginwindow".TALLogoutSavesState   = false;
    };
  };

  # ── Activation Scripts ───────────────────────────────────────────────────── #
  system.activationScripts.extraActivation.text = ''
    if ! /usr/bin/pgrep -q oahd; then
      softwareupdate --install-rosetta --agree-to-license
    fi
  '';
}
