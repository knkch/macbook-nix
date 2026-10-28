{ pkgs, ... }:
let
  # sketchybar のプラグイン（nix store に置くので相対パス問題が起きない）
  plugin = name: text: pkgs.writeShellScript "sketchybar-${name}" text;

  space = plugin "space" ''
    focused="''${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
    if [ "$1" = "$focused" ]; then
      sketchybar --set "$NAME" background.drawing=on label.color=0xff1a1b26
    else
      sketchybar --set "$NAME" background.drawing=off label.color=0xffc0caf5
    fi
  '';

  frontApp = plugin "front-app" ''
    if [ "$SENDER" = "front_app_switched" ]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
  '';

  clock = plugin "clock" ''
    sketchybar --set "$NAME" label="$(date '+%m/%d(%a) %H:%M')"
  '';

  battery = plugin "battery" ''
    info="$(pmset -g batt)"
    pct="$(echo "$info" | grep -Eo '[0-9]+%' | tr -d '%')"
    [ -z "$pct" ] && exit 0
    if echo "$info" | grep -q 'AC Power'; then icon="󰂄"
    elif [ "$pct" -ge 80 ]; then icon="󰁹"
    elif [ "$pct" -ge 50 ]; then icon="󰁿"
    elif [ "$pct" -ge 20 ]; then icon="󰁻"
    else icon="󰁺"; fi
    sketchybar --set "$NAME" icon="$icon" label="''${pct}%"
  '';

  volume = plugin "volume" ''
    if [ "$SENDER" = "volume_change" ]; then
      vol="$INFO"
    else
      vol="$(osascript -e 'output volume of (get volume settings)')"
    fi
    if   [ "$vol" -ge 60 ]; then icon="󰕾"
    elif [ "$vol" -ge 1  ]; then icon="󰖀"
    else icon="󰖁"; fi
    sketchybar --set "$NAME" icon="$icon" label="''${vol}%"
  '';
in
{
  # ── Jankyborders（ウィンドウ枠線）────────────────────────────────────────── #
  services.jankyborders = {
    enable         = true;
    style          = "round";
    width          = 5.0;
    hidpi          = true;
    active_color   = "0xc0ff00f2";
    inactive_color = "0xff0080ff";
  };

  # ── Sketchybar（ステータスバー）──────────────────────────────────────────── #
  # aerospace CLI は Homebrew cask 提供（/opt/homebrew/bin は systemPath 経由で PATH に入る）
  services.sketchybar = {
    enable = false;
    config = ''
      sketchybar --bar position=top height=32 blur_radius=30 color=0xcc1a1b26 \
        padding_left=8 padding_right=8

      sketchybar --default \
        icon.font="Hack Nerd Font:Bold:15.0" \
        label.font="Hack Nerd Font:Bold:13.0" \
        icon.color=0xffc0caf5 label.color=0xffc0caf5 \
        padding_left=4 padding_right=4 \
        icon.padding_left=4 icon.padding_right=4 \
        label.padding_left=4 label.padding_right=4

      # ── 左: AeroSpace ワークスペース 1〜9 ──
      sketchybar --add event aerospace_workspace_change
      for sid in 1 2 3 4 5 6 7 8 9; do
        sketchybar --add item "space.$sid" left \
          --subscribe "space.$sid" aerospace_workspace_change \
          --set "space.$sid" \
            label="$sid" icon.drawing=off \
            background.color=0xff7aa2f7 background.corner_radius=5 \
            background.height=22 background.drawing=off \
            click_script="aerospace workspace $sid" \
            script="${space} $sid"
      done

      # ── 左: 前面アプリ ──
      sketchybar --add item front_app left \
        --subscribe front_app front_app_switched \
        --set front_app icon.drawing=off label.color=0xff9ece6a script="${frontApp}"

      # ── 右: 時計 / バッテリー / 音量 ──
      sketchybar --add item clock right \
        --set clock icon="󰥔" update_freq=10 script="${clock}"

      sketchybar --add item battery right \
        --subscribe battery system_woke power_source_change \
        --set battery update_freq=120 script="${battery}"

      sketchybar --add item volume right \
        --subscribe volume volume_change \
        --set volume script="${volume}"

      sketchybar --update
    '';
  };
}
