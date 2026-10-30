ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── 前面アプリ ────────────────────────────────────────────────────────── #
  # 標準メニューバーは sketchybar の裏に隠れているので、アプリのメニュー（ファイル・編集…）を
  # ここから開く。押すとメニューの名前を一覧にし、選ぶと本物のメニューが開く（app-menu）
  frontApp = plugin "front-app" (header + ''
    # メニューは ax-agent が読む（1 行目が前面アプリの pid、2 行目から「<番号> US <名前>」）
    build_menu() {
      local p=front_app pid i name
      { IFS= read -r pid
        if [ -z "$pid" ] || [ "''${pid#ERROR}" != "$pid" ]; then
          menu_item $p none "" "メニューを読めません（sketchybar-doctor で確認）"
        else
          while IFS=$'\x1f' read -r i name; do
            [ -n "$name" ] && menu_item $p "m.$i" "" "$name" app-menu "$pid" "$i"
          done
        fi
      } < <(ax menus)
      menu_item $p search "󰍉" "メニューを検索（⌘⇧/）" app-menu-search
    }
    handle_popup

    if [ "$SENDER" = "front_app_switched" ]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
  '');
}
