# 各プラグインが読み込む共通関数（sketchybar-lib.sh）: 色・メニューの作り方・集中モード・カレンダー
ctx:
let
  inherit (ctx) calEvent calRender focusModes hover jq pkgs wifiSsid;
in
rec {
  # ── 共通関数（各プラグインが読み込む）──────────────────────────────────── #
  # メニュー（ポップアップ）は開くたびに中身を作り直し、最新の状態を表示する。
  # 項目名は「<親>.dyn.<名前>」。クリック時の操作は $ACTION（action スクリプト）に渡す。
  shLib = pkgs.writeText "sketchybar-lib.sh" ''
    FG=0xffc0caf5; SUB=0xff9aa5ce; DIM=0xff565f89; ACCENT=0xff7aa2f7; GREEN=0xff9ece6a; RED=0xfff7768e
    POPUPS="apple front_app clock notify input battery volume bluetooth wifi vpn music"
    MPC=${pkgs.mpc}/bin/mpc
    # アクセシビリティが必要な操作は ax-agent に頼む（pkgs/ax-agent。許可は ax-agent だけに与え、sketchybar には与えない）
    ax() { printf '%s\n' "$*" | /usr/bin/nc -U -w 2 "$HOME/Library/Caches/sketchybar-ax/sock" 2>/dev/null; }
    # 通知を「すべて消去」した時刻（Mac の日時 = 2001-01-01 からの秒数）。これより前の通知は表示しない
    NOTIFY_CLEARED="$HOME/Library/Caches/sketchybar-notify-cleared"
    WIFI_SCAN="$HOME/Library/Caches/sketchybar-wifi-scan" # 直近のスキャン結果
    WIFI_HOTSPOTS="$HOME/Library/Caches/sketchybar-wifi-hotspots" # メニューに出したテザリングの機器（1 行 1 台）
    WIFI_EXPANDED="$HOME/Library/Caches/sketchybar-wifi-expanded" # あれば Wi-Fi の一覧を広げて表示
    WIFI_FOLD=5 # たたんだときに出す Wi-Fi の件数
    # カレンダー: 選んだ日（YYYY-MM-DD）・画像の置き場所・予定の行数
    CAL_SEL="''${TMPDIR:-/tmp}/sketchybar-cal-selected"
    CAL_DIR="''${TMPDIR:-/tmp}/sketchybar-calendar"
    CAL_EVENT_ROWS=5
    CAL_STATE="''${TMPDIR:-/tmp}/sketchybar-cal-offset" # カレンダーで表示中の月（今月からのずれ）

    wifi_dev() { networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}'; }
    preferred_networks() { networksetup -listpreferredwirelessnetworks "$1" | tail -n +2 | sed 's/^[[:space:]]*//'; }
    # 今つながっているネットワーク名。取れなければ、直近のスキャン結果から
    # 同じチャンネルで電波の強さが一番近いものを推定する
    wifi_ssid() {
      local ssid ch rssi
      IFS=$'\x1f' read -r ssid ch rssi < <(osascript -l JavaScript ${wifiSsid} 2>/dev/null)
      if [ -n "$ssid" ]; then echo "$ssid"; return; fi
      [ -n "$ch" ] && [ -f "$WIFI_SCAN" ] || return 0
      awk -F"$(printf '\037')" -v ch="$ch" -v rssi="$rssi" '
        $4 == ch { d = $2 - rssi; if (d < 0) d = -d; if (best == "" || d < bd) { best = $1; bd = d } }
        END { if (best != "") print best }' "$WIFI_SCAN"
    }
    # 集中モードの切り替え用ショートカット（名前が「集中モード: 」で始まるもの）
    # ショートカットの名前は濁点が分かれた形（NFD。「ド」=「ト」+「゛」）で返ってくるので、
    # 比べるときは nfc で濁点をまとめた形にそろえる。実行するときは元の名前のまま使う
    nfc() { iconv -f UTF-8-MAC -t UTF-8 2>/dev/null; }
    focus_shortcuts() {
      shortcuts list 2>/dev/null | while IFS= read -r n; do
        case "$(printf '%s' "$n" | nfc)" in "集中モード: "*) echo "$n" ;; esac
      done
    }
    # 「集中モード: <名前> オン / オフ」のショートカットがある集中モードの名前（重複なし）
    focus_modes() { focus_shortcuts | nfc | sed -E 's/^集中モード: //; s/ (オン|オフ)$//' | awk '!seen[$0]++'; }
    # 集中モードの名前 → macOS の識別子（focusModes に書いたモードだけ。それ以外は空）
    focus_id() {
      case "$1" in
    ${pkgs.lib.concatMapStrings (m: "    ${pkgs.lib.escapeShellArg m.name}) echo ${m.id} ;;\n") focusModes}
      esac
    }
    # 今オンになっている集中モードの識別子（保護領域なので protected-reader が書き出したものを読む）
    focus_active() {
      cat "$HOME/Library/Caches/sketchybar-protected/focus" 2>/dev/null
    }
    # focus_row_args <行の番号> <名前>: 行の見た目（オンなら ● と緑、オフなら ○）を ARGS に足す
    focus_row_args() {
      local id; id="$(focus_id "$2")"
      if [ -n "$id" ] && focus_active | grep -qx "$id"; then
        ARGS+=(--set "notify.dyn.focus.$1" icon="●" icon.color=$GREEN label="$2（オン）" label.color=$GREEN)
      else
        ARGS+=(--set "notify.dyn.focus.$1" icon="○" icon.color=$SUB label="$2" label.color=$FG)
      fi
    }

    # クリックできる行（ハイライトし、幅を揃える）と、メニュー幅いっぱいで中央に寄せる行
    CLICKABLE_ROWS=(); CENTER_ROWS=(); SECTION_ROWS=()
    # メニューの中身はここに貯めて、最後に 1 回の sketchybar 呼び出しでまとめて送る。
    # 途中で別の処理（裏のスキャン後の作り直しなど）が割り込んで行の順番が崩れないように
    BATCH=()
    HOVER_STYLE=(background.color=0xff2f3549 background.corner_radius=5 background.height=24
                 background.drawing=off script="${hover}")

    # クリックできる行: ハイライトを付けて、マウスの出入りを受け取る
    make_clickable() {
      CLICKABLE_ROWS+=("$1")
      BATCH+=(--set "$1" "''${HOVER_STYLE[@]}" --subscribe "$1" mouse.entered mouse.exited)
    }

    # 行の幅の見積もり（実測から: 英数字 1 文字 ≒ 7.5、全角 ≒ 12.5）。表示する前に幅を決めて、
    # 表示後に幅が変わってメニューがずれないようにする
    MAX_WIDTH=0
    estimate() { # estimate <テキスト> <土台の幅> <英数字の幅> <全角の幅>
      local LC_ALL=en_US.UTF-8 text="$1" ascii n w
      ascii="''${text//[^ -~]/}"
      n=''${#text}
      w=$(( $2 + (''${#ascii} * $3 + (n - ''${#ascii}) * $4) / 10 ))
      [ "$w" -gt "$MAX_WIDTH" ] && MAX_WIDTH=$w
      return 0
    }
    # クリックできる行の幅を、一番広い行の見積もりに揃える（build_menu の後・表示の前に呼ぶ）
    apply_widths() {
      local row
      for row in "''${CLICKABLE_ROWS[@]}"; do BATCH+=(--set "$row" width="$MAX_WIDTH"); done
      for row in "''${CENTER_ROWS[@]}"; do BATCH+=(--set "$row" width="$MAX_WIDTH" align=center); done
      for row in "''${SECTION_ROWS[@]}"; do BATCH+=(--set "$row" width="$MAX_WIDTH"); done
      return 0
    }

    # 曜日（日本語 1 文字）。引数なしなら今日
    weekday_ja() {
      local d="''${1:-$(date +%F)}"
      case "$(date -j -f %Y-%m-%d "$d" +%u 2>/dev/null)" in
        1) echo 月 ;; 2) echo 火 ;; 3) echo 水 ;; 4) echo 木 ;; 5) echo 金 ;; 6) echo 土 ;; *) echo 日 ;;
      esac
    }

    # 表示中の月（CAL_STATE = 今月からのずれ）を画像で描く。
    # CAL_IMG に 月送り / 曜日 / 1〜6 週目 の画像のパスが入る（$CAL_DIR/dates に各週の日付）
    cal_render() {
      local off sign y m
      off="$(cat "$CAL_STATE" 2>/dev/null || echo 0)"
      if [ "$off" -ge 0 ]; then sign="+$off"; else sign="$off"; fi
      read -r y m < <(date -v1d -v"''${sign}m" '+%Y %-m')
      read -r -a CAL_IMG < <(${calRender} "$y" "$m" "$(cat "$CAL_SEL" 2>/dev/null || echo -)" "$CAL_DIR" 2>/dev/null)
      [ ''${#CAL_IMG[@]} -eq 8 ]
    }
    # 画像を差し替える指定を ARGS に足す（行は作り直さない）
    cal_image_args() {
      local i
      ARGS+=(--set clock.dyn.cal.nav background.image="''${CAL_IMG[0]}" slider.percentage=0
             --set clock.dyn.cal.head background.image="''${CAL_IMG[1]}")
      for i in 1 2 3 4 5 6; do
        ARGS+=(--set "clock.dyn.cal.w$i" background.image="''${CAL_IMG[$((i + 1))]}" slider.percentage=0)
      done
    }
    # 選んだ日の予定を、用意してある行（見出し + CAL_EVENT_ROWS 行）に入れる指定を ARGS に足す。
    # 各行の予定の ID などを $CAL_DIR/events に保存（行を押すと編集・削除できる）
    cal_event_args() {
      local sel line i lines=() LC_ALL=en_US.UTF-8
      sel="$(cat "$CAL_SEL" 2>/dev/null)"; [ -n "$sel" ] || sel="$(date +%F)"
      ARGS+=(--set clock.dyn.h.ev label="$(date -j -f %Y-%m-%d "$sel" '+%-m月%-d日' 2>/dev/null)（$(weekday_ja "$sel")）の予定")
      mkdir -p "$CAL_DIR"
      ${calEvent} list "$sel" 2>/dev/null | grep . > "$CAL_DIR/events"
      while IFS=$'\x1f' read -r _ line _; do
        [ -n "$line" ] && lines+=("$line")
      done < "$CAL_DIR/events"
      [ ''${#lines[@]} -eq 0 ] && lines=("予定はありません")
      for i in $(seq 1 "$CAL_EVENT_ROWS"); do
        line="''${lines[$((i - 1))]}"
        if [ "$i" -eq "$CAL_EVENT_ROWS" ] && [ ''${#lines[@]} -gt "$CAL_EVENT_ROWS" ]; then
          line="ほか $(( ''${#lines[@]} - CAL_EVENT_ROWS + 1 )) 件"
        fi
        if [ -n "$line" ]; then ARGS+=(--set "clock.dyn.ev.$i" label="$line" drawing=on)
        else ARGS+=(--set "clock.dyn.ev.$i" drawing=off); fi
      done
    }

    # メニューの外に出てから閉じるまでの秒数と、その印を置く場所（handle_popup・hover）
    POPUP_CLOSE_DELAY=0.6
    POPUP_CLOSE_DIR="$HOME/Library/Caches/sketchybar-popup-close"

    close_all() {
      local args=() p
      for p in $POPUPS; do args+=(--set "$p" popup.drawing=off); done
      sketchybar "''${args[@]}"
    }

    # menu_item <親> <名前> <アイコン> <ラベル> [操作 引数...]（操作なし = 情報表示だけの行）
    menu_item() {
      local parent="$1" name="$2" icon="$3" label="$4"; shift 4
      local style=(icon="$icon" label="$label" icon.padding_left=10 icon.padding_right=8 label.padding_right=16)
      [ -z "$icon" ] && style+=(icon.drawing=off label.padding_left=12) # アイコンなしの行
      if [ $# -gt 0 ]; then style+=(icon.color=$FG label.color=$FG click_script="$ACTION $*")
      else style+=(icon.color=$SUB label.color=$SUB); fi
      BATCH+=(--add item "$parent.dyn.$name" popup."$parent" --set "$parent.dyn.$name" "''${style[@]}")
      estimate "$label" 62 75 125
      [ $# -gt 0 ] && make_clickable "$parent.dyn.$name"
      return 0
    }

    # menu_header <親> <名前> <見出し>
    menu_header() {
      BATCH+=(--add item "$1.dyn.$2" popup."$1" --set "$1.dyn.$2" icon.drawing=off
        label="$3" label.font="Hack Nerd Font:Bold:11.0" label.color=$ACCENT
        label.padding_left=10 padding_left=0)
      estimate "$3" 24 65 110
    }

    # menu_section <親> <名前> <見出し>: 行の上端に区切り線を引いた見出し（前のまとまりと分ける）。
    # 線は行の背景を高さ 1 にして上へずらしたもの（行の高さはバーと同じ 33）。幅はメニューの幅に揃える
    menu_section() {
      menu_header "$1" "$2" "$3"
      BATCH+=(--set "$1.dyn.$2" background.drawing=on background.color=0xff414868
        background.height=1 background.y_offset=15)
      SECTION_ROWS+=("$1.dyn.$2")
    }

    # menu_slider <親> <名前> <アイコン> <割合> <スクリプト>
    menu_slider() {
      BATCH+=(--add slider "$1.dyn.$2" popup."$1" 180
        --set "$1.dyn.$2" icon="$3" icon.padding_left=10 icon.padding_right=8
          label="$4%" label.width=44 label.align=right label.padding_right=4 label.color=$SUB
          slider.percentage="$4" slider.highlight_color=$ACCENT
          slider.background.height=6 slider.background.corner_radius=3 slider.background.color=0xff414868
          slider.knob="●" slider.knob.color=$FG padding_right=16 script="$5"
        --subscribe "$1.dyn.$2" mouse.clicked)
      [ "$MAX_WIDTH" -lt 290 ] && MAX_WIDTH=290
      return 0
    }

    # クリックでメニューを開閉（開くときに各プラグインの build_menu で中身を作る）
    handle_popup() {
      case "$SENDER" in
        mouse.clicked)
          if [ "$(sketchybar --query "$NAME" | ${jq} -r .popup.drawing)" = on ]; then
            sketchybar --set "$NAME" popup.drawing=off
          else
            close_all
            build_menu
            apply_widths
            sketchybar --remove "/$NAME\.dyn\..*/" "''${BATCH[@]}" --set "$NAME" popup.drawing=on 2>/dev/null
          fi
          exit 0 ;;
        # マウスが項目とメニューの外に出ても、すぐには閉じない（少しはみ出しただけで閉じないように）。
        # 出たときに印を置いて少し待ち、その間に戻らなければ閉じる。戻ったら（項目か、メニューの
        # クリックできる行に入ったら）印を消す（行の側は hover スクリプト）
        mouse.exited.global)
          mkdir -p "$POPUP_CLOSE_DIR"
          local mark="$$.$RANDOM"
          echo "$mark" > "$POPUP_CLOSE_DIR/$NAME"
          sleep "$POPUP_CLOSE_DELAY"
          if [ "$(cat "$POPUP_CLOSE_DIR/$NAME" 2>/dev/null)" = "$mark" ]; then
            rm -f "$POPUP_CLOSE_DIR/$NAME"
            sketchybar --set "$NAME" popup.drawing=off
          fi
          exit 0 ;;
        mouse.entered)
          rm -f "$POPUP_CLOSE_DIR/$NAME"
          exit 0 ;;
        # 開いたまま中身だけ作り直す（sketchybar --trigger menu_rebuild TARGET=<項目>）
        menu_rebuild)
          if [ "$TARGET" = "$NAME" ]; then
            build_menu
            apply_widths
            sketchybar --remove "/$NAME\.dyn\..*/" "''${BATCH[@]}" 2>/dev/null
          fi
          exit 0 ;;
      esac
    }
  '';
}
