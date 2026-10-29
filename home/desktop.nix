{ lib, osConfig, ... }:
let
  workspaces = map toString (lib.range 1 9);
in
{
  # ── AeroSpace ────────────────────────────────────────────────────────────── #
  # 本体は Homebrew cask（nikitabobko/tap/aerospace）、設定のみ home-manager で生成
  # sketchybar / jankyborders は modules/desktop.nix（nix-darwin の services）
  programs.aerospace = {
    enable  = true;
    package = null;
    userSettings = {
      start-at-login = true;

      # sketchybar にワークスペース切り替えを通知（AeroSpace は PATH が最小なので絶対パス）
      # sketchybar 無効時は通知しない
      exec-on-workspace-change = lib.optionals osConfig.services.sketchybar.enable [
        "/bin/bash" "-c"
        "/run/current-system/sw/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];

      gaps = {
        # top: 内蔵画面（ノッチあり）は macOS がメニューバー分を空けたままにするので 5、
        #      外部モニターはバーの高さ 32 + 5
        outer = { left = 5; right = 5; top = [ { monitor.built-in = 5; } 37 ]; bottom = 5; };
        inner = { horizontal = 5; vertical = 5; };
      };

      mode.main.binding = {
        # Focus
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        # Move
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        # Layout
        alt-f       = "fullscreen";
        alt-shift-f = "layout floating tiling";
        alt-slash   = "layout tiles horizontal vertical";
        alt-comma   = "layout accordion horizontal vertical";

        # Monitor
        alt-tab       = "move-workspace-to-monitor next";
        alt-shift-tab = "focus-monitor next";
      }
      # Workspaces: alt-N で移動 / alt-shift-N でウィンドウを送る
      // lib.genAttrs (map (n: "alt-${n}") workspaces) (k: "workspace ${lib.removePrefix "alt-" k}")
      // lib.genAttrs (map (n: "alt-shift-${n}") workspaces) (k: "move-node-to-workspace ${lib.removePrefix "alt-shift-" k}");
    };
  };

  # ── Ghostty ──────────────────────────────────────────────────────────────── #
  xdg.configFile."ghostty/config".text = ''
    font-family = Hack Nerd Font Mono
    font-size = 12
    background-opacity = 0.85
    background-blur-radius = 20
    theme = dark:tokyonight,light:tokyonight-day
    cursor-style = bar
    cursor-style-blink = true
    shell-integration = zsh
    copy-on-select = clipboard
    window-padding-x = 8
    window-padding-y = 8
  '';
}
