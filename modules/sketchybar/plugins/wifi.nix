ctx:
let
  inherit (ctx) blueutil header plugin wifiScan;
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
    # テザリングできる機器の名前: Bluetooth でペアリング済みで、Wi-Fi でも過去につないだもの
    # （iPhone のパーソナルホットスポットのネットワーク名は、その iPhone の名前と同じ）
    hotspot_devices() {
      local dev="$1"
      grep -xF -f <(preferred_networks "$dev") \
        <(${blueutil} --paired 2>/dev/null | sed -n 's/.*name: "\([^"]*\)".*/\1/p') 2>/dev/null | awk '!seen[$0]++'
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
      local p=wifi dev ip eth ssid router dns i=0 j=0 n=0 hidden=0 expanded=0 net hs
      dev="$(wifi_dev)"
      if [ "$(networksetup -getairportpower "$dev" | awk '{print $NF}')" = On ]; then
        menu_item $p power "󰐥" "Wi-Fi: オン（クリックでオフ）" wifi-power off
        ip="$(ipconfig getifaddr "$dev" 2>/dev/null)"
        ssid="$(wifi_ssid)"
        hs="$(hotspot_devices "$dev")"
        printf '%s\n' "$hs" > "$WIFI_HOTSPOTS" # 押したときの操作は番号で受け取り、ここから名前を引く
        if [ -n "$ip" ]; then menu_item $p status "󰖩" "接続中: ''${ssid:-（名前を取得できません）}"
        else menu_item $p status "󰖪" "未接続"; fi

        # 検出したネットワーク（開いた時は前回の結果を出し、裏でスキャンして更新）
        # 一覧は電波の強い順に WIFI_FOLD 件だけ出し、残りは「ほかのネットワーク」でたたむ（押すと広げる。wifi-more）。
        # 開くたびにたたんだ状態に戻す
        [ "$SENDER" = "mouse.clicked" ] && rm -f "$WIFI_EXPANDED"
        [ -f "$WIFI_EXPANDED" ] && expanded=1
        if [ "$SENDER" = "mouse.clicked" ]; then
          start_scan
          menu_header $p h.scan "ネットワーク（検索中…）"
        else
          menu_header $p h.scan "ネットワーク（クリックで接続）"
        fi
        while IFS=$'\x1f' read -r net rssi open ch; do
          n=$((n + 1)) # スキャン結果の行番号（wifi-scan-join はこれで名前を引く）
          [ -z "$net" ] && continue
          printf '%s\n' "$hs" | grep -qxF "$net" && continue # テザリングの機器は下のまとまりに出す
          i=$((i + 1))
          [ "$i" -gt 15 ] && break
          # たたんでいるときは上位だけ（接続中のものは順位に関係なく出す）
          if [ "$expanded" = 0 ] && [ "$i" -gt "$WIFI_FOLD" ] && [ "$net" != "$ssid" ]; then
            hidden=$((hidden + 1)); continue
          fi
          if [ "$net" = "$ssid" ]; then
            menu_item $p "net.$n" "󰄬" "$net"
          else
            menu_item $p "net.$n" "$(signal_icon "$rssi" "$open")" "$net" wifi-scan-join "$n"
          fi
        done 2>/dev/null < "$WIFI_SCAN"
        if [ "$i" -eq 0 ]; then menu_item $p net.none "󰖩" "検索中です…"
        elif [ "$hidden" -gt 0 ]; then menu_item $p more "󰅀" "ほかのネットワーク（''${hidden}）" wifi-more 1
        elif [ "$expanded" = 1 ] && [ "$i" -gt "$WIFI_FOLD" ]; then menu_item $p more "󰅃" "たたむ" wifi-more 0
        fi

        # テザリング（iPhone のパーソナルホットスポット）は Wi-Fi の一覧と分けて出す。
        # 押すと、電波が出ていればそのまま接続し、出ていなければ標準の Wi-Fi メニューを開く（wifi-hotspot）
        menu_section $p h.hotspot "パーソナルホットスポット"
        while IFS= read -r net; do
          [ -z "$net" ] && continue
          j=$((j + 1))
          if [ "$net" = "$ssid" ]; then menu_item $p "hs.$j" "󰄬" "''${net}（接続中）"
          else menu_item $p "hs.$j" "󰄜" "$net" wifi-hotspot "$j"; fi
        done <<< "$hs"
        [ "$j" -eq 0 ] && menu_item $p hs.none "󰄜" "iPhone のテザリング…" wifi-hotspot
      else
        menu_item $p power "󰐥" "Wi-Fi: オフ（クリックでオン）" wifi-power on
      fi

      menu_section $p h.detail "詳細"
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
