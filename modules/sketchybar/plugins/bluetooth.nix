ctx:
let
  inherit (ctx) blueutil header plugin;
in
rec {
  # ── Bluetooth ─────────────────────────────────────────────────────────── #
  bluetooth = plugin "bluetooth" (header + ''
    build_menu() {
      local p=bluetooth line addr name i=0
      if [ "$(${blueutil} -p)" = 1 ]; then
        menu_item $p power "󰐥" "Bluetooth: オン（クリックでオフ）" bt-power 0
        menu_header $p h.dev "デバイス（クリックで接続 / 切断）"
        while IFS= read -r line; do
          addr="$(printf '%s' "$line" | sed -n 's/^address: \([^,]*\),.*/\1/p')"
          name="$(printf '%s' "$line" | sed -n 's/.*name: "\([^"]*\)".*/\1/p')"
          [ -z "$addr" ] && continue
          i=$((i + 1))
          if printf '%s' "$line" | grep -q ', connected'; then
            menu_item $p "dev.$i" "󰂱" "''${name:-$addr}（接続中）" bt-disconnect "$addr"
          else
            menu_item $p "dev.$i" "󰂯" "''${name:-$addr}" bt-connect "$addr"
          fi
        done < <(${blueutil} --paired 2>/dev/null)
        [ "$i" -eq 0 ] && menu_item $p none "󰂯" "登録済みのデバイスはありません"
      else
        menu_item $p power "󰐥" "Bluetooth: オフ（クリックでオン）" bt-power 1
      fi
      menu_item $p settings "󰒓" "Bluetooth 設定…" bt-settings
    }
    handle_popup

    if [ "$(${blueutil} -p)" = 1 ]; then
      if [ -n "$(${blueutil} --connected 2>/dev/null)" ]; then icon="󰂱"; color=$ACCENT
      else icon="󰂯"; color=$FG; fi
    else
      icon="󰂲"; color=$DIM
    fi
    sketchybar --set "$NAME" icon="$icon" icon.color="$color"
  '');
}
