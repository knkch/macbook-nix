ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── Apple メニュー ──────────────────────────────────────────────────────── #
  apple = plugin "apple" (header + ''
    build_menu() {
      local p=apple
      menu_item $p about    "󰋼"    "この Mac について"         about
      menu_item $p settings "󰒓"     "システム設定…"             settings
      menu_item $p swupdate "󰑐" "ソフトウェアアップデート…" swupdate
      menu_item $p store    "󰓜"   "App Store…"                appstore
      menu_item $p activity "󰄪"   "アクティビティモニタ"      activity
      menu_header $p h.power "電源"
      menu_item $p sleep    "󰒲"   "スリープ"                  sleep
      menu_item $p lock     "󰌾"    "画面をロック"              lock
      menu_item $p restart  "󰜉" "再起動…"                   restart
      menu_item $p shutdown "󰐥"   "システム終了…"             shutdown
      menu_item $p logout   "󰍃"  "ログアウト…"               logout
    }
    handle_popup
  '');
}
