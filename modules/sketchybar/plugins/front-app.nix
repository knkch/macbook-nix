ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── 前面アプリ ────────────────────────────────────────────────────────── #
  # 標準メニューバーは sketchybar の裏に隠れているので、アプリのメニュー（ファイル・編集…）を
  # ここから開く。押すとメニューの名前を一覧にし、選ぶと本物のメニューが開く（app-menu）
  frontApp = plugin "front-app" (header + ''
    # 前面アプリの pid と、メニューバーの項目名（1 行目が pid、2 行目から名前。Apple メニューは除く）
    app_menus() {
      osascript <<'AS' 2>/dev/null
    tell application "System Events"
      set p to first process whose frontmost is true
      set names to name of menu bar items of menu bar 1 of p
      set out to (unix id of p as text)
      repeat with i from 2 to count of names
        set out to out & linefeed & (item i of names)
      end repeat
      return out
    end tell
    AS
    }

    build_menu() {
      local p=front_app pid name i=1
      { read -r pid
        while IFS= read -r name; do
          i=$((i + 1))
          [ -n "$name" ] && menu_item $p "m.$i" "" "$name" app-menu "$pid" "$i"
        done
      } < <(app_menus)
      [ -z "$pid" ] && menu_item $p none "" "メニューを読めません（アクセシビリティの許可を確認）"
      menu_item $p search "󰍉" "メニューを検索（⌘⇧/）" app-menu-search
    }
    handle_popup

    if [ "$SENDER" = "front_app_switched" ]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
  '');
}
