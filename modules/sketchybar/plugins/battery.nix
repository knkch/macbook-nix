ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── バッテリー ────────────────────────────────────────────────────────── #
  battery = plugin "battery" (header + ''
    # 電力モード（pmset の powermode: 0 = 自動 / 1 = 低電力 / 2 = 高出力）を選ぶ行
    # power_modes <b = バッテリー | c = 電源アダプタ> <見出し>
    power_modes() {
      local section cur m icon label
      if [ "$1" = b ]; then section="Battery Power"; else section="AC Power"; fi
      cur="$(pmset -g custom | awk -v s="$section:" '$0 == s {f = 1; next} /^[A-Z]/ {f = 0} f && $1 == "powermode" {print $2}')"
      menu_header battery "h.pm$1" "$2"
      for m in 0 1 2; do
        if [ "$m" = "''${cur:-0}" ]; then icon="󰐾"; else icon="󰐽"; fi
        case "$m" in 0) label="自動" ;; 1) label="低電力" ;; 2) label="高出力" ;; esac
        menu_item battery "pm$1.$m" "$icon" "$label" power-mode "$1" "$m"
      done
    }

    build_menu() {
      local p=battery info pct src remain lpm
      info="$(pmset -g batt)"
      pct="$(echo "$info" | grep -Eo '[0-9]+%' | head -1)"
      if echo "$info" | grep -q 'AC Power'; then src="電源アダプタ"; else src="バッテリー"; fi
      remain="$(echo "$info" | grep -Eo '[0-9]+:[0-9]+ remaining' | cut -d' ' -f1)"
      if echo "$info" | grep -q 'charged'; then remain="充電完了"
      elif [ -z "$remain" ]; then remain="計算中"
      elif echo "$info" | grep -q 'AC Power'; then remain="満充電まで $remain"
      else remain="残り $remain"; fi
      menu_item $p pct    "󰁹" "残量 ''${pct:-?}"
      menu_item $p src    "󰂄"  "電源: $src"
      menu_item $p remain "󰥔"    "$remain"
      power_modes b "電力モード（バッテリー）"
      power_modes c "電力モード（電源アダプタ）"
      menu_item $p activity "󰄪" "アクティビティモニタ" activity
      menu_item $p settings "󰒓"   "バッテリー設定…"      battery-settings
    }
    handle_popup

    info="$(pmset -g batt)"
    pct="$(echo "$info" | grep -Eo '[0-9]+%' | tr -d '%')"
    [ -z "$pct" ] && exit 0
    if echo "$info" | grep -q 'AC Power'; then icon="󰂄"
    elif [ "$pct" -ge 80 ]; then icon="󰁹"
    elif [ "$pct" -ge 50 ]; then icon="󰁿"
    elif [ "$pct" -ge 20 ]; then icon="󰁻"
    else icon="󰁺"; fi
    sketchybar --set "$NAME" icon="$icon" label="''${pct}%"
  '');
}
