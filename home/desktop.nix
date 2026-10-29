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

      # ── レイアウト ──
      # 通常のウィンドウは必ずタイル表示（重ならないように並べる）
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 0; # アコーディオン（alt-,）でもずらして重ねない

      # フローティングは一時的な小さいウィンドウだけ（ダイアログ・シート等は AeroSpace が自動で浮かせる）。
      # フローティングはタイルの後ろに隠れることがある（AeroSpace は常に手前に出せない）ので、
      # 普通に使うウィンドウ（システム設定など）はタイルのままにする。
      on-window-detected = [
        # ピクチャインピクチャ
        { "if".window-title-regex-substring = "(Picture.in.Picture|ピクチャ.?イン.?ピクチャ)"; run = [ "layout floating" ]; }
        # Finder の「情報を見る」・コピー / 移動中の進行状況
        { "if".app-id = "com.apple.finder"; "if".window-title-regex-substring = "(の情報$|^コピー|^移動|Info$|^Copy)"; run = [ "layout floating" ]; }
        # 展開の進行状況・カラーピッカー
        { "if".app-id = "com.apple.archiveutility";    run = [ "layout floating" ]; }
        { "if".app-id = "com.apple.DigitalColorMeter"; run = [ "layout floating" ]; }
      ];

      gaps = {
        # 隙間はすべて 3（jankyborders の枠線 2 もこれに合わせている。sketchybar の左右の端の余白は 12）
        # top: 標準メニューバーは常に表示（sketchybar で覆う）ので、macOS がその分を空ける。
        #      内蔵画面（ノッチあり）はメニューバー ≒ バー 33 なので 3、
        #      外部モニターはメニューバー 24 前後 → バー 33 との差 9 + 3 = 12
        outer = { left = 3; right = 3; top = [ { monitor.built-in = 3; } 12 ]; bottom = 3; };
        inner = { horizontal = 3; vertical = 3; };
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
