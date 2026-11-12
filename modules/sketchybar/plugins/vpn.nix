ctx:
let
  inherit (ctx) header jq plugin tailscale;
in
rec {
  # ── VPN（Tailscale とシステムの VPN 設定）──────────────────────────────── #
  vpn = plugin "vpn" (header + ''
    ts_json() { ${tailscale} status --json 2>/dev/null; }
    # システムの VPN 一覧（Tailscale は別枠で扱うので除外）: "<ID>\t<状態>\t<名前>"
    vpn_services() {
      scutil --nc list 2>/dev/null | tail -n +2 | grep -v 'io.tailscale' | while IFS= read -r line; do
        printf '%s\t%s\t%s\n' \
          "$(printf '%s' "$line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)" \
          "$(printf '%s' "$line" | grep -oE '\((Connected|Connecting|Disconnected|Disconnecting|Invalid)\)' | tr -d '()')" \
          "$(printf '%s' "$line" | sed -n 's/[^"]*"\([^"]*\)".*/\1/p')"
      done
    }

    build_menu() {
      local p=vpn json state ip i=0 id st name exit_ip cur_exit host on icon
      json="$(ts_json)"
      state="$(printf '%s' "$json" | ${jq} -r '.BackendState // empty' 2>/dev/null)"
      ip="$(printf '%s' "$json" | ${jq} -r '.Self.TailscaleIPs[0] // empty' 2>/dev/null)"

      menu_header $p h.ts "Tailscale"
      case "$state" in
        Running)
          menu_item $p ts.status "󰖂"   "接続中 ($ip)"
          menu_item $p ts.toggle "󰐥" "切断する" ts-down
          # 出口ノード（すべての通信を経由させる端末）
          cur_exit="$(printf '%s' "$json" | ${jq} -r '.Peer[]? | select(.ExitNode) | .TailscaleIPs[0]' 2>/dev/null)"
          if printf '%s' "$json" | ${jq} -e '[.Peer[]? | select(.ExitNodeOption)] | length > 0' >/dev/null 2>&1; then
            menu_header $p h.exit "出口ノード"
            if [ -z "$cur_exit" ]; then icon="󰐾"; else icon="󰐽"; fi
            menu_item $p exit.none "$icon" "使わない" ts-exit ""
            while IFS="$(printf '\t')" read -r exit_ip host; do
              i=$((i + 1))
              if [ "$exit_ip" = "$cur_exit" ]; then icon="󰐾"; else icon="󰐽"; fi
              menu_item $p "exit.$i" "$icon" "$host" ts-exit "$exit_ip"
            done < <(printf '%s' "$json" | ${jq} -r '.Peer[]? | select(.ExitNodeOption) | [.TailscaleIPs[0], .HostName] | @tsv')
          fi ;;
        Stopped)
          menu_item $p ts.status "󰖂"   "切断中"
          menu_item $p ts.toggle "󰐥" "接続する" ts-up ;;
        NeedsLogin)
          menu_item $p ts.status "󰖂"   "未ログイン（アプリからログイン）" ;;
        *)
          menu_item $p ts.status "󰖂"   "起動していません" ;;
      esac
      menu_item $p ts.app "󰏌" "Tailscale を開く" ts-app

      menu_header $p h.vpn "VPN（クリックで接続 / 切断）"
      i=0
      while IFS="$(printf '\t')" read -r id st name; do
        [ -z "$id" ] && continue
        i=$((i + 1))
        case "$st" in
          Connected)  menu_item $p "vpn.$i" "󰖂" "''${name}（接続中）" vpn-stop "$id" ;;
          Connecting) menu_item $p "vpn.$i" "󰖂" "''${name}（接続処理中）" vpn-stop "$id" ;;
          *)          menu_item $p "vpn.$i" "󰖂" "$name" vpn-start "$id" ;;
        esac
      done < <(vpn_services)
      [ "$i" -eq 0 ] && menu_item $p vpn.none "󰖂" "設定された VPN はありません"
      menu_item $p settings "󰒓" "VPN 設定…" vpn-settings
    }
    handle_popup

    state="$(ts_json | ${jq} -r '.BackendState // empty' 2>/dev/null)"
    if [ "$state" = Running ] || vpn_services | cut -f2 | grep -qx Connected; then color=$GREEN; else color=$DIM; fi
    sketchybar --set "$NAME" icon.color="$color"
  '');
}
