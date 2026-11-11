# メニューの行を押したときの操作（sketchybar-action）
ctx:
let
  inherit (ctx) blueutil calEvent calTimePicker focusShortcuts plugin sas shLib tailscale ymuse;
in
rec {
  # ── メニュー項目から呼ぶ操作 ──────────────────────────────────────────── #
  action = plugin "action" ''
    . ${shLib}
    # メニュー内の操作（カレンダーの月送り）以外はメニューを閉じる
    case "$1" in cal-* | notify-clear | focus-toggle) ;; *) close_all ;; esac

    # 入力画面の部品（どれもキャンセルなら失敗を返す）。画面のタイトルは DIALOG_TITLE
    DIALOG_TITLE="予定"
    # ask <説明> [初期値]: 文字を入力
    ask() {
      osascript - "$1" "''${2:-}" "$DIALOG_TITLE" <<'AS' 2>/dev/null
    on run argv
      text returned of (display dialog (item 1 of argv) default answer (item 2 of argv) with title (item 3 of argv) buttons {"キャンセル", "OK"} default button "OK" cancel button "キャンセル")
    end run
    AS
    }
    # choose <説明> <改行区切りの候補（最初が初期値）>: 一覧から選ぶ
    choose() {
      local r
      r="$(osascript - "$1" "$2" "$DIALOG_TITLE" <<'AS' 2>/dev/null
    on run argv
      set choices to paragraphs of (item 2 of argv) -- items は予約語なので使えない
      set r to choose from list choices with title (item 3 of argv) with prompt (item 1 of argv) default items {item 1 of choices}
      if r is false then return ""
      return item 1 of r
    end run
    AS
    )"
      [ -n "$r" ] && echo "$r"
    }
    # confirm <説明> <実行ボタン>: 確認（実行ボタンなら成功）
    confirm() {
      osascript - "$1" "$2" "$DIALOG_TITLE" <<'AS' >/dev/null 2>&1
    on run argv
      display dialog (item 1 of argv) with title (item 3 of argv) buttons {"キャンセル", item 2 of argv} default button "キャンセル" cancel button "キャンセル"
    end run
    AS
    }
    # notify_msg <タイトル> <本文>: macOS の通知
    notify_msg() {
      osascript - "$1" "$2" <<'AS' >/dev/null 2>&1
    on run argv
      display notification (item 2 of argv) with title (item 1 of argv)
    end run
    AS
    }

    # pick_time <見出し> [開始 終了]: プルダウンで時間を選んで START / END に入れる（終日 = 両方空）。
    # 編集で終日の予定なら pick_time <見出し> "" "" のように空を渡すと「終日」にチェックが入った状態で開く
    pick_time() {
      local r
      r="$(${calTimePicker} "$@" 2>/dev/null)"
      case "$r" in
        allday) START=""; END="" ;;
        *:*" "*:*) START="''${r% *}"; END="''${r#* }" ;;
        *) return 1 ;; # キャンセル
      esac
    }
    # ask_alarm <開始時刻（空なら終日）> [今の通知の分（空 = なし）]: 通知のタイミングを尋ねて
    # ALARM（分。空 = なし）に入れる。今の設定（追加のときは 10 分前 / 当日 9:00）を初期値にする
    ask_alarm() {
      local cur list label
      if [ -n "$1" ]; then
        case "''${2-new}" in
          new) cur="10分前" ;; "") cur="なし" ;; 0) cur="開始時" ;; 60) cur="1時間前" ;; *) cur="''${2}分前" ;;
        esac
        list="$(printf '%s\n' "$cur" 10分前 なし 開始時 5分前 30分前 1時間前 | awk '!seen[$0]++')"
      else
        case "''${2-new}" in "") cur="なし" ;; *) cur="当日 9:00" ;; esac
        list="$(printf '%s\n' "$cur" "当日 9:00" なし | awk '!seen[$0]++')"
      fi
      label="$(choose "通知" "$list")" || return 1
      case "$label" in
        なし) ALARM="" ;; 開始時 | "当日 9:00") ALARM=0 ;; 1時間前) ALARM=60 ;;
        *分前) ALARM="''${label%分前}" ;; *) ALARM=0 ;;
      esac
    }
    # カレンダーの画像と予定の行を更新
    cal_refresh() { ARGS=(); cal_render && cal_image_args; cal_event_args; sketchybar "''${ARGS[@]}"; }

    pane() { open "x-apple.systempreferences:$1"; }
    refresh() { sleep "$1"; sketchybar --update; }
    # click_menuextra <clock / audiovideo / wifi>: 隠れている標準メニューバーの項目をクリック（ax-agent に頼む。失敗なら偽）
    click_menuextra() { [ "$(ax extra-click "$1")" = ok ]; }

    case "$1" in
      # Apple メニュー
      about)    pane com.apple.SystemProfiler.AboutExtension ;;
      settings) open -a "System Settings" ;;
      swupdate) pane com.apple.Software-Update-Settings.extension ;;
      appstore) open -a "App Store" ;;
      activity) open -a "Activity Monitor" ;;
      sleep)    pmset sleepnow ;;
      lock)     pmset displaysleepnow ;; # パスワード要求が「すぐに」ならロックされる
      restart)  osascript -e 'tell application "loginwindow" to «event aevtrrst»' ;; # 確認ダイアログが出る
      shutdown) osascript -e 'tell application "loginwindow" to «event aevtrsdn»' ;;
      logout)   osascript -e 'tell application "loginwindow" to «event aevtrlgo»' ;;

      # 設定画面・アプリ
      wifi-settings)     pane com.apple.wifi-settings-extension ;;
      network-settings)  pane com.apple.Network-Settings.extension ;;
      bt-settings)       pane com.apple.BluetoothSettings ;;
      vpn-settings)      pane com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension ;;
      sound-settings)    pane com.apple.Sound-Settings.extension ;;
      battery-settings)  pane com.apple.Battery-Settings.extension ;;

      # 音楽（mpd）
      music-toggle) $MPC toggle >/dev/null ;;
      music-prev)   $MPC prev >/dev/null ;;
      music-next)   $MPC next >/dev/null ;;
      music-stop)   $MPC stop >/dev/null ;;
      # 今の曲のあいだだけバーから隠す（隠した曲を記録し、music_update で表示を更新）
      music-hide)
        $MPC current -f '%file%' > "''${TMPDIR:-/tmp}/sketchybar-music-hidden" 2>/dev/null
        sketchybar --trigger music_update ;;
      # mpd の GUI（ymuse）を開く。rmpc と同じ mpd を操作するので再生リストも共通。すでに開いていればそのウィンドウを出す
      # （cmux は外のプロセスからの操作を受け付けないので、rmpc を開く方式はやめた）
      music-open)   nohup ${ymuse} >/dev/null 2>&1 & ;;
      # 電力モードの変更（引数: b / c と 0 / 1 / 2）。管理者のパスワードを macOS の画面で尋ねる
      power-mode)
        case "$2$3" in b0|b1|b2|c0|c1|c2) ;; *) exit 0 ;; esac
        osascript -e "do shell script \"/usr/bin/pmset -$2 powermode $3\" with administrator privileges" >/dev/null 2>&1
        refresh 0 ;;
      datetime-settings) pane com.apple.Date-Time-Settings.extension ;;
      internet-accounts) pane com.apple.Internet-Accounts-Settings.extension ;;
      notify-settings)   pane com.apple.Notifications-Settings.extension ;;
      keyboard-settings) pane com.apple.Keyboard-Settings.extension ;;

      # 入力ソース: キー操作を送る（ax-agent に頼む）
      ime-next) ax key ime-next >/dev/null ;;
      emoji)    ax key emoji >/dev/null ;;
      focus-settings)    pane com.apple.Focus-Settings.extension ;;
      # 「ショートカットを追加…」: focusModes のショートカットが足りなければ取り込み画面を開き、
      # そろっていればショートカットアプリを開く（自分で作るとき用）
      shortcuts-app)
        ${focusShortcuts}/bin/focus-shortcuts --check >/dev/null 2>&1
        if [ $? -eq 1 ]; then ${focusShortcuts}/bin/focus-shortcuts >/dev/null 2>&1; else open -a Shortcuts; fi ;;
      # アプリのメニュー（引数: pid と、メニューバーでの番号）。隠れている標準メニューバーの項目を
      # ax-agent が押して、本物のメニューを開く（前面アプリのものだけ）
      app-menu)        ax menu-open "$2" "$3" >/dev/null ;;
      # メニューの検索（ヘルプメニューの検索欄）を開く
      app-menu-search) sleep 0.1; ax key menu-search >/dev/null ;;
      open-app)          open -b "$2" ;; # 通知をクリック → そのアプリを開く
      # 通知を「すべて消去」: 今の時刻を記録して、メニューとベルの件数を作り直す（macOS 側の通知は残る）
      notify-clear)
        mkdir -p "$(dirname "$NOTIFY_CLEARED")"
        echo $(( $(date +%s) - 978307200 )) > "$NOTIFY_CLEARED"
        sketchybar --trigger menu_rebuild TARGET=notify
        sketchybar --trigger notify_update ;;
      fda-settings)     open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" ;;

      # 集中モードのオン / オフを切り替える（引数: 行の番号と名前）。今の状態の逆のショートカットを実行し、その行だけ更新
      focus-toggle)
        id="$(focus_id "$3")"
        if [ -n "$id" ] && focus_active | grep -qx "$id"; then want="オフ"; else want="オン"; fi
        sc="$(focus_shortcuts | while IFS= read -r n; do [ "$(printf '%s' "$n" | nfc)" = "集中モード: $3 $want" ] && echo "$n"; done | head -1)"
        [ -n "$sc" ] || exit 0
        shortcuts run "$sc" >/dev/null 2>&1 &   # まれに終わらないことがあるので待ちすぎない
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          sleep 0.3
          if [ "$want" = オン ]; then focus_active | grep -qx "$id" && break; else focus_active | grep -qx "$id" || break; fi
        done
        # 状態が変わらなければ知らせる（その集中モードがシステム設定で追加されていない場合など）
        if [ -n "$id" ]; then
          if [ "$want" = オン ]; then focus_active | grep -qx "$id" || failed=1; else focus_active | grep -qx "$id" && failed=1; fi
          [ -n "$failed" ] && notify_msg "集中モード" "「$3」を切り替えられませんでした。システム設定の「集中モード」に追加されているか確認してください"
        fi
        ARGS=(); focus_row_args "$2" "$3"; sketchybar "''${ARGS[@]}" ;;

      # カレンダーの月送り（引数: 月数 / 0 = 今月）
      # メニューは作り直さず、月送りの行とカレンダーの画像だけ差し替える
      # （行を消して作り直すと、直後のクリックが古い行に向かい、別の見えない行が拾ってメニューが閉じる）
      cal-shift)
        off="$(cat "$CAL_STATE" 2>/dev/null || echo 0)"
        if [ "$2" = 0 ]; then off=0; else off=$((off + $2)); fi
        echo "$off" > "$CAL_STATE"
        ARGS=(); cal_render && cal_image_args
        [ ''${#ARGS[@]} -gt 0 ] && sketchybar "''${ARGS[@]}" ;;
      # 選んだ日に予定を追加: タイトル → 時間（プルダウン / 終日）→ カレンダー → 通知 の順に尋ねて EventKit で登録
      cal-add)
        DIALOG_TITLE="予定を追加"
        sel="$(cat "$CAL_SEL" 2>/dev/null)"; [ -n "$sel" ] || sel="$(date +%F)"
        day="$(date -j -f %Y-%m-%d "$sel" '+%-m月%-d日' 2>/dev/null)（$(weekday_ja "$sel")）"
        title="$(ask "$day に追加する予定のタイトル")" || exit 0
        [ -n "$title" ] || exit 0
        pick_time "$day の時間" || exit 0
        cals="$(${calEvent} calendars 2>/dev/null)"
        if [ "$(printf '%s\n' "$cals" | grep -c .)" -gt 1 ]; then
          cal="$(choose "登録するカレンダー" "$cals")" || exit 0
        else
          cal="$cals"
        fi
        ask_alarm "$START" || exit 0
        result="$(${calEvent} add "$sel" "$title" "$START" "$END" "$cal" "$ALARM" 2>&1)"
        if [ "$result" = ok ]; then cal_refresh; else notify_msg "予定を追加できませんでした" "$result"; fi ;;

      # 予定の行を押したとき（引数: 行の番号）: 編集（タイトル・時間・通知）か削除
      cal-edit)
        DIALOG_TITLE="予定"
        IFS=$'\x1f' read -r id label editable < <(sed -n "$2p" "$CAL_DIR/events" 2>/dev/null)
        [ -n "$id" ] || exit 0
        if [ "$editable" != 1 ]; then notify_msg "変更できない予定です" "$label（祝日など、読み取り専用のカレンダー）"; exit 0; fi
        what="$(choose "$label" "$(printf '%s\n' 編集… 削除)")" || exit 0
        if [ "$what" = 削除 ]; then
          confirm "「$label」を削除しますか？" 削除 || exit 0
          result="$(${calEvent} delete "$id" 2>&1)"
        else
          DIALOG_TITLE="予定を編集"
          IFS=$'\x1f' read -r title day start end alarm cal < <(${calEvent} get "$id" 2>/dev/null)
          title="$(ask "タイトル" "$title")" || exit 0
          [ -n "$title" ] || exit 0
          pick_time "$title の時間" "$start" "$end" || exit 0
          ask_alarm "$START" "$alarm" || exit 0
          result="$(${calEvent} update "$id" "$title" "$START" "$END" "$ALARM" 2>&1)"
        fi
        if [ "$result" = ok ]; then cal_refresh; else notify_msg "予定を変更できませんでした" "$result"; fi ;;

      # 日付を選ぶ（引数: 週 1〜6 と曜日の列 0〜6）→ 輪を付け直して、その日の予定を表示
      cal-select)
        sel="$(sed -n "$2p" "$CAL_DIR/dates" 2>/dev/null | cut -d' ' -f$(( $3 + 1 )))"
        [ -n "$sel" ] || exit 0
        echo "$sel" > "$CAL_SEL"
        ARGS=(); cal_render && cal_image_args
        cal_event_args
        sketchybar "''${ARGS[@]}" ;;

      # 通知センター: 隠れている標準メニューバーの時計をクリックして開く（失敗したら通知設定を開く）
      nc-open)
        click_menuextra clock || pane com.apple.Notifications-Settings.extension ;;

      # 音量・オーディオデバイス（引数は一覧での番号）
      mute)
        osascript -e 'set volume output muted (not (output muted of (get volume settings)))'
        refresh 0 ;;
      audio-out) ${sas} -t output -s "$(${sas} -a -t output | sed -n "$2p")" >/dev/null ;;
      audio-in)  ${sas} -t input  -s "$(${sas} -a -t input  | sed -n "$2p")" >/dev/null ;;

      # Bluetooth（引数はデバイスのアドレス）
      bt-power)      ${blueutil} -p "$2"; refresh 1 ;;
      bt-connect)    ${blueutil} --connect "$2"; refresh 1 ;;
      bt-disconnect) ${blueutil} --disconnect "$2"; refresh 1 ;;

      # Wi-Fi
      wifi-power)
        networksetup -setairportpower "$(wifi_dev)" "$2"
        refresh 3 ;;
      # 検出したネットワークに接続（引数はスキャン結果での番号）
      wifi-scan-join)
        dev="$(wifi_dev)"
        IFS=$'\x1f' read -r ssid rssi open < <(sed -n "$2p" "$WIFI_SCAN")
        [ -z "$ssid" ] && exit 0
        if [ "$open" = 1 ] || preferred_networks "$dev" | grep -qxF "$ssid"; then
          out="$(networksetup -setairportnetwork "$dev" "$ssid" 2>&1)"
        else
          # パスワードを尋ねる（キャンセルなら何もしない）
          pw="$(osascript - "$ssid" <<'AS' 2>/dev/null
    on run argv
      text returned of (display dialog ("「" & item 1 of argv & "」のパスワード") default answer "" with hidden answer with title "Wi-Fi に接続")
    end run
    AS
    )" || exit 0
          out="$(networksetup -setairportnetwork "$dev" "$ssid" "$pw" 2>&1)"
        fi
        [ -n "$out" ] && notify_msg "Wi-Fi に接続できませんでした" "$out"
        refresh 3 ;;
      # iPhone のテザリング（インスタントホットスポット）: CoreWLAN のスキャンには出ないので、
      # 標準メニューバーの Wi-Fi メニューを開き、その「パーソナルホットスポット」から選んでもらう
      wifi-hotspot)
        click_menuextra wifi \
          || notify_msg "iPhone のテザリング" "Wi-Fi メニューを開けませんでした（ax-agent の許可を確認: sketchybar-doctor）" ;;
      # ビデオエフェクト（ポートレート・センターフレーム・背景など）: カメラ使用中だけ標準メニューバーに出る
      # 「オーディオとビデオのコントロール」をクリックして開く
      camera-effects)
        click_menuextra audiovideo \
          || notify_msg "ビデオエフェクト" "カメラを使っているときだけ開けます" ;;

      # BetterDisplay（HiDPI・解像度）: BetterDisplay 自身の命令でメニューを開く（アクセシビリティは要らない。
      # 隠れたメニューバーの項目を押す方法では、BetterDisplay が前面に来るだけでメニューが出なかった）。
      # 命令はすぐに終わらないことがあるので裏で実行する。動いていなければ起動だけする
      display)
        if pgrep -xq BetterDisplay; then
          /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay set -appMenu=on >/dev/null 2>&1 &
        else
          open -a BetterDisplay
        fi ;;

      # Tailscale
      ts-up)   ${tailscale} up;   refresh 2 ;;
      ts-down) ${tailscale} down; refresh 2 ;;
      ts-exit) ${tailscale} set --exit-node="$2"; refresh 2 ;; # 空 = 出口ノードを使わない
      ts-app)  open -a Tailscale ;;

      # その他の VPN（引数はサービス ID）
      vpn-start) scutil --nc start "$2"; refresh 3 ;;
      vpn-stop)  scutil --nc stop "$2";  refresh 2 ;;
    esac
  '';
}
