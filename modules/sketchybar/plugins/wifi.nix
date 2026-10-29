ctx:
let
  inherit (ctx) header plugin wifiScan;
in
rec {
  # ── ネットワーク（有線 / Wi-Fi）───────────────────────────────────────── #
  wifi = plugin "wifi" (header + ''
    # 有線: Wi-Fi 以外の en* で IP を持っているもの（"<デバイス> <IP>" を返す）
    ethernet() {
      local d ip
      for d in $(networksetup -listallhardwareports | awk '/Device: en/{print $2}'); do
        [ "$d" = "$1" ] && continue
        ip="$(ipconfig getifaddr "$d" 2>/dev/null)"
        [ -n "$ip" ] && { echo "$d $ip"; return; }
      done
    }
    # 電波の強さ（RSSI）と鍵の有無 → アイコン
    signal_icon() {
      local rssi="$1" open="$2" level
      if   [ "$rssi" -ge -55 ]; then level=4
      elif [ "$rssi" -ge -67 ]; then level=3
      elif [ "$rssi" -ge -78 ]; then level=2
      else level=1; fi
      case "$level$open" in
        41) echo "󰤨" ;; 40) echo "󰤪" ;;
        31) echo "󰤥" ;; 30) echo "󰤧" ;;
        21) echo "󰤢" ;; 20) echo "󰤤" ;;
        11) echo "󰤟" ;; *)  echo "󰤡" ;;
      esac
    }

    # 周囲のネットワークを裏でスキャンし、終わったらメニューを作り直す
    start_scan() {
      local lock="$WIFI_SCAN.lock"
      find "$lock" -maxdepth 0 -mmin +1 -exec rmdir {} \; 2>/dev/null
      mkdir "$lock" 2>/dev/null || return 0 # すでにスキャン中
      (
        trap 'rmdir "$lock" 2>/dev/null' EXIT
        tmp="$(mktemp)"
        osascript -l JavaScript ${wifiScan} > "$tmp" 2>/dev/null && [ -s "$tmp" ] && mkdir -p "$(dirname "$WIFI_SCAN")" && mv "$tmp" "$WIFI_SCAN"
        rm -f "$tmp"
        sketchybar --trigger menu_rebuild TARGET=wifi
      ) >/dev/null 2>&1 &
      disown
    }

    build_menu() {
      local p=wifi dev ip eth ssid router dns i=0 net
      dev="$(wifi_dev)"
      if [ "$(networksetup -getairportpower "$dev" | awk '{print $NF}')" = On ]; then
        menu_item $p power "󰐥" "Wi-Fi: オン（クリックでオフ）" wifi-power off
        ip="$(ipconfig getifaddr "$dev" 2>/dev/null)"
        ssid="$(wifi_ssid)"
        if [ -n "$ip" ]; then menu_item $p status "󰖩" "接続中: ''${ssid:-（名前を取得できません）}"
        else menu_item $p status "󰖪" "未接続"; fi

        # 検出したネットワーク（開いた時は前回の結果を出し、裏でスキャンして更新）
        if [ "$SENDER" = "mouse.clicked" ]; then
          start_scan
          menu_header $p h.scan "ネットワーク（検索中…）"
        else
          menu_header $p h.scan "ネットワーク（クリックで接続）"
        fi
        while IFS=$'\x1f' read -r net rssi open ch; do
          [ -z "$net" ] && continue
          i=$((i + 1))
          [ "$i" -gt 15 ] && break
          if [ "$net" = "$ssid" ]; then
            menu_item $p "net.$i" "󰄬" "$net"
          else
            menu_item $p "net.$i" "$(signal_icon "$rssi" "$open")" "$net" wifi-scan-join "$i"
          fi
        done 2>/dev/null < "$WIFI_SCAN"
        [ "$i" -eq 0 ] && menu_item $p net.none "󰖩" "検索中です…"
      else
        menu_item $p power "󰐥" "Wi-Fi: オフ（クリックでオン）" wifi-power on
      fi

      menu_header $p h.detail "詳細"
      eth="$(ethernet "$dev")"
      [ -n "$eth" ] && menu_item $p eth "󰈀" "有線 (''${eth% *}): ''${eth#* }"
      [ -n "$ip" ] && menu_item $p ip "󰌗" "Wi-Fi IP: $ip"
      router="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')"
      # DNS は IPv4 を優先（なければ最初のもの）
      dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\] : [0-9.]+$/{print $3; exit}')"
      [ -z "$dns" ] && dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[0\]/{print $3; exit}')"
      menu_item $p router "󰑩" "ルーター: ''${router:--}"
      menu_item $p dns    "󰌗"    "DNS: ''${dns:--}"

      menu_item $p wsettings "󰒓" "Wi-Fi 設定…"        wifi-settings
      menu_item $p nsettings "󰒓" "ネットワーク設定…"  network-settings
    }
    handle_popup

    # バーはアイコンだけ（名前を出すと幅が変わって右側の項目がずれる）
    dev="$(wifi_dev)"
    power="$(networksetup -getairportpower "$dev" | awk '{print $NF}')"
    if [ -n "$(ethernet "$dev")" ]; then
      icon="󰈀"; color=$FG
    elif [ -n "$(ipconfig getifaddr "$dev" 2>/dev/null)" ]; then
      icon="󰖩"; color=$FG
    elif [ "$power" = On ]; then
      icon="󰖪"; color=$RED
    else
      icon="󰖪"; color=$DIM
    fi
    sketchybar --set "$NAME" icon="$icon" icon.color="$color" label.drawing=off
  '');
}
