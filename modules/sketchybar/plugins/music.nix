ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── 再生中の曲（mpd）。ノッチのすぐ左 ─────────────────────────────────────── #
  # mpc idle で再生状態の変化を待ち、変わったら music_update を送る（ループは 1 本だけ）。
  # 停止中は「停止中」、mpd が動いていないときは「オフ」と小さく表示する
  music = plugin "music" (header + ''
    pidfile="''${TMPDIR:-/tmp}/sketchybar-music.pid"
    if ! { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }; then
      (
        while sketchybar --query music >/dev/null 2>&1; do
          $MPC idle player options >/dev/null 2>&1 || sleep 5 # mpd が止まっていたら 5 秒ごとに再試行
          sketchybar --trigger music_update
        done
      ) >/dev/null 2>&1 &
      echo $! > "$pidfile"
      disown
    fi

    build_menu() {
      local p=music
      if [ -n "$($MPC current 2>/dev/null)" ]; then
        menu_header $p h.song "$($MPC current -f '%album%' 2>/dev/null)"
        menu_item $p title  "󰝚" "$($MPC current -f '%title%' 2>/dev/null)"
        menu_item $p artist "" "$($MPC current -f '%artist%' 2>/dev/null)"
      else
        menu_item $p title  "󰝚" "再生していません"
      fi
      menu_item $p prev   "󰒮" "前の曲"            music-prev
      if [ "$($MPC status '%state%' 2>/dev/null)" = playing ]; then
        menu_item $p toggle "󰏤" "一時停止"         music-toggle
      else
        menu_item $p toggle "󰐊" "再生"             music-toggle
      fi
      menu_item $p next   "󰒭" "次の曲"            music-next
      menu_item $p open   "󰏌" "ymuse を開く"            music-open
      menu_item $p stop   "󰓛" "停止"                      music-stop
      menu_item $p hide   "󰈉" "曲名を隠す（次の曲で再表示）"   music-hide
    }
    handle_popup

    # 状態: playing / paused / stopped。mpd に接続できなければ off
    state="$($MPC status '%state%' 2>/dev/null)" || state=off
    [ -n "$state" ] || state=off
    # 「曲名を隠す」を選んだ曲のあいだはアイコンだけにする（曲が変わったら曲名に戻る）
    hidden="$(cat "''${TMPDIR:-/tmp}/sketchybar-music-hidden" 2>/dev/null)"
    [ -n "$hidden" ] && [ "$hidden" = "$($MPC current -f '%file%' 2>/dev/null)" ] && state=hidden
    case "$state" in
      playing | paused)
        if [ "$state" = playing ]; then icon="󰝚"; color=$FG; else icon="󰏤"; color=$SUB; fi
        sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label.color="$color" \
          label.drawing=on label="$($MPC current -f '[%artist% - ]%title%|%file%' 2>/dev/null)" ;;
      # 消さずに小さく残す（クリックでメニューから再生などができる）
      hidden)
        sketchybar --set "$NAME" drawing=on icon="󰝚" icon.color=$SUB label.drawing=off ;;
      stopped)
        sketchybar --set "$NAME" drawing=on icon="󰝚" icon.color=$DIM label.color=$DIM label.drawing=on label="停止中" ;;
      *)
        sketchybar --set "$NAME" drawing=on icon="󰝚" icon.color=$DIM label.color=$DIM label.drawing=on label="オフ" ;;
    esac
  '');
}
