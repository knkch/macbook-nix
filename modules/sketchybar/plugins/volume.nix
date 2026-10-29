ctx:
let
  inherit (ctx) header plugin sas;
in
rec {
  # ── 音量 ──────────────────────────────────────────────────────────────── #
  # メニュー内のスライダー（出力 / 入力の音量）
  volumeSlider = plugin "volume-slider" ''
    [ "$SENDER" = "mouse.clicked" ] || exit 0
    case "$NAME" in
      *.out) osascript -e "set volume output volume $PERCENTAGE" ;;
      *.in)  osascript -e "set volume input volume $PERCENTAGE" ;;
    esac
    sketchybar --set "$NAME" slider.percentage="$PERCENTAGE" label="$PERCENTAGE%"
  '';

  volume = plugin "volume" (header + ''
    vget() { osascript -e "$1 of (get volume settings)"; }
    # 出力 / 入力デバイスの一覧（現在のものに印）
    device_list() {
      local p=volume type="$1" cur dev i=0 icon
      cur="$(${sas} -c -t "$type")"
      while IFS= read -r dev; do
        i=$((i + 1))
        if [ "$dev" = "$cur" ]; then icon="󰐾"; else icon="󰐽"; fi
        menu_item $p "$type.$i" "$icon" "$dev" "audio-$([ "$type" = output ] && echo out || echo in)" "$i"
      done < <(${sas} -a -t "$type")
    }
    build_menu() {
      local p=volume vol invol
      vol="$(vget 'output volume')"; invol="$(vget 'input volume')"
      menu_header $p h.out "出力"
      menu_slider $p slider.out "󰓃" "''${vol:-0}" "${volumeSlider}"
      if [ "$(vget 'output muted')" = true ]; then menu_item $p mute "󰖁" "ミュートを解除" mute
      else menu_item $p mute "󰖁" "ミュート" mute; fi
      device_list output
      menu_header $p h.in "入力"
      menu_slider $p slider.in "󰍬" "''${invol:-0}" "${volumeSlider}"
      device_list input
      menu_item $p settings "󰒓" "サウンド設定…" sound-settings
    }
    handle_popup

    # スクロールで音量調整
    if [ "$SENDER" = "mouse.scrolled" ]; then
      new=$(( $(vget 'output volume') + SCROLL_DELTA * 3 ))
      [ "$new" -lt 0 ] && new=0
      [ "$new" -gt 100 ] && new=100
      osascript -e "set volume output volume $new"
    fi
    if [ "$SENDER" = "volume_change" ]; then vol="$INFO"; else vol="$(vget 'output volume')"; fi
    case "$vol" in "" | *[!0-9]*) vol=0 ;; esac # 出力先によっては取得できない
    if [ "$(vget 'output muted')" = true ] || [ "$vol" -eq 0 ]; then icon="󰖁"
    elif [ "$vol" -ge 60 ]; then icon="󰕾"
    else icon="󰖀"; fi
    sketchybar --set "$NAME" icon="$icon" label="''${vol}%"
    sketchybar --set volume.dyn.slider.out slider.percentage="$vol" label="$vol%" >/dev/null 2>&1
  '');
}
