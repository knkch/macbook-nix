{ pkgs, ... }:
{
  # ── AeroSpace ────────────────────────────────────────────────────────────── #
  # macOS Spaces を1つにして AeroSpace Workspaces に一本化
  # System Settings → Desktop & Dock → "Displays have separate Spaces" も要オフ
  # programs.aerospace DSL は home-manager 25.05 に未対応のため xdg.configFile で管理
  xdg.configFile."aerospace/aerospace.toml".text = ''
    [gaps]
    outer.left   = 5
    outer.right  = 5
    outer.top    = 5
    outer.bottom = 5
    inner.horizontal = 5
    inner.vertical   = 5

    [mode.main.binding]
    # Focus
    alt-h = 'focus left'
    alt-j = 'focus down'
    alt-k = 'focus up'
    alt-l = 'focus right'

    # Move
    alt-shift-h = 'move left'
    alt-shift-j = 'move down'
    alt-shift-k = 'move up'
    alt-shift-l = 'move right'

    # Layout
    alt-f       = 'fullscreen'
    alt-shift-f = 'layout floating tiling'
    alt-slash   = 'layout tiles horizontal vertical'
    alt-comma   = 'layout accordion horizontal vertical'

    # Workspaces — focus
    alt-1 = 'workspace 1'
    alt-2 = 'workspace 2'
    alt-3 = 'workspace 3'
    alt-4 = 'workspace 4'
    alt-5 = 'workspace 5'
    alt-6 = 'workspace 6'
    alt-7 = 'workspace 7'
    alt-8 = 'workspace 8'
    alt-9 = 'workspace 9'

    # Workspaces — move node
    alt-shift-1 = 'move-node-to-workspace 1'
    alt-shift-2 = 'move-node-to-workspace 2'
    alt-shift-3 = 'move-node-to-workspace 3'
    alt-shift-4 = 'move-node-to-workspace 4'
    alt-shift-5 = 'move-node-to-workspace 5'
    alt-shift-6 = 'move-node-to-workspace 6'
    alt-shift-7 = 'move-node-to-workspace 7'
    alt-shift-8 = 'move-node-to-workspace 8'
    alt-shift-9 = 'move-node-to-workspace 9'

    # Monitor
    alt-tab       = 'move-workspace-to-monitor next'
    alt-shift-tab = 'focus-monitor next'
  '';

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

  # ── Jankyborders ─────────────────────────────────────────────────────────── #
  launchd.agents.jankyborders = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.jankyborders}/bin/borders"
        "style=round"
        "width=5.0"
        "hidpi=on"
        "active_color=0xc0ff00f2"
        "inactive_color=0xff0080ff"
      ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # ── Sketchybar ───────────────────────────────────────────────────────────── #
  # brew services で起動するため launchd agent は定義しない
  xdg.configFile."sketchybar/sketchybarrc" = {
    source     = ../config/sketchybar/sketchybarrc;
    executable = true;
  };
}
