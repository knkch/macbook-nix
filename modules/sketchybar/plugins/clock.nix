ctx:
let
  inherit (ctx) action header plugin;
in
rec {
  # ── 時計 ──────────────────────────────────────────────────────────────── #
  # カレンダーの月送り行。行全体をスライダーにして画像（‹ 年月 ›）を敷き、クリック位置で分ける
  # （左 2 割 = 前の月 / 右 2 割 = 次の月 / 真ん中 = 今月）。スライダーは帯の外のクリックを無視するため
  # 週の行も同じ作り。押した位置（7 等分）からその日を選ぶ
  calWeek = plugin "cal-week" ''
    [ "$SENDER" = "mouse.clicked" ] || exit 0
    col=$(( ''${PERCENTAGE:-0} * 7 / 100 )); [ "$col" -gt 6 ] && col=6
    exec ${action} cal-select "''${NAME##*.w}" "$col"
  '';

  calNav = plugin "cal-nav" ''
    [ "$SENDER" = "mouse.clicked" ] || exit 0
    if   [ "''${PERCENTAGE:-50}" -lt 20 ]; then exec ${action} cal-shift -1
    elif [ "''${PERCENTAGE:-50}" -gt 80 ]; then exec ${action} cal-shift 1
    else exec ${action} cal-shift 0; fi
  '';



  # 時刻・月カレンダー・選んだ日の予定をメニュー内に表示（外部アプリは開かない）
  clock = plugin "clock" (header + ''
    # 月カレンダー: 月送り・曜日・6 週の行を画像で並べる（幅 224）。
    # 画像は行の背景に敷き、月送りと週の行は透明なスライダーにして押した位置を受け取る
    # （スライダーの帯に画像を敷くと二重に描かれる。帯の外のクリックは無視される）
    calendar() {
      local p=clock i
      cal_render || return 0
      BATCH+=(--add slider "$p.dyn.cal.nav" popup."$p" 224
        --set "$p.dyn.cal.nav" icon.drawing=off label.drawing=off
          background.drawing=on background.color=0x00000000 background.height=30 background.image.scale=0.5
          slider.percentage=0 slider.knob="" slider.highlight_color=0x00000000
          slider.background.drawing=on slider.background.color=0x00000000 slider.background.height=30
          script="${calNav}"
        --subscribe "$p.dyn.cal.nav" mouse.clicked
        --add item "$p.dyn.cal.head" popup."$p"
        --set "$p.dyn.cal.head" icon.drawing=off label.drawing=off width=224
          background.drawing=on background.color=0x00000000 background.height=22 background.image.scale=0.5)
      for i in 1 2 3 4 5 6; do
        BATCH+=(--add slider "$p.dyn.cal.w$i" popup."$p" 224
          --set "$p.dyn.cal.w$i" icon.drawing=off label.drawing=off
            background.drawing=on background.color=0x00000000 background.height=26 background.image.scale=0.5
            slider.percentage=0 slider.knob="" slider.highlight_color=0x00000000
            slider.background.drawing=on slider.background.color=0x00000000 slider.background.height=26
            script="${calWeek}"
          --subscribe "$p.dyn.cal.w$i" mouse.clicked)
      done
      [ "$MAX_WIDTH" -lt 232 ] && MAX_WIDTH=232
      ARGS=(); cal_image_args; BATCH+=("''${ARGS[@]}")
    }

    # 選んだ日の予定（行は先に用意しておき、日付を選ぶたびに中身だけ差し替える）
    events() {
      local p=clock i
      menu_header $p h.ev "予定"
      for i in $(seq 1 "$CAL_EVENT_ROWS"); do menu_item $p "ev.$i" "󰃭" "" cal-edit "$i"; done # 押すと編集・削除
      menu_item $p ev.add "󰐕" "予定を追加…" cal-add
      ARGS=(); cal_event_args; BATCH+=("''${ARGS[@]}")
    }

    build_menu() {
      local p=clock i pad
      BATCH+=(--add item "$p.dyn.now" popup."$p" --set "$p.dyn.now" icon.drawing=off
        label="$(date '+%H:%M')" label.font="Hack Nerd Font:Bold:22.0" label.color=$FG
        label.padding_left=0 label.padding_right=0 # 大きな時刻は高めの行に
        background.drawing=on background.color=0x00000000 background.height=40)
      CENTER_ROWS+=("$p.dyn.now")
      calendar
      events
      menu_item $p accounts "󰒓" "カレンダーのアカウント…" internet-accounts # Google / Outlook などを追加すると同期される
      menu_item $p dt "󰒓" "日付と時刻設定…" datetime-settings
      # カレンダーの画像（幅 224）をメニューの中央に。予定の行はメニュー幅に収める
      pad=$(( 4 + (MAX_WIDTH - 224) / 2 ))
      for i in nav head w1 w2 w3 w4 w5 w6; do BATCH+=(--set "$p.dyn.cal.$i" padding_left=$pad); done
      for i in $(seq 1 "$CAL_EVENT_ROWS"); do BATCH+=(--set "$p.dyn.ev.$i" width="$MAX_WIDTH" label.max_chars=15); done
    }

    # 開くたびに今月・今日を選んだ状態から
    if [ "$SENDER" = "mouse.clicked" ]; then echo 0 > "$CAL_STATE"; date +%F > "$CAL_SEL"; fi
    handle_popup
    sketchybar --set "$NAME" label="$(date '+%m/%d')($(weekday_ja)) $(date '+%H:%M')"
  '');
}
