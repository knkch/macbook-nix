{ pkgs, ... }:
let
  # sketchybar のプラグイン（nix store に置くので相対パス問題が起きない）
  plugin = name: text: pkgs.writeShellScript "sketchybar-${name}" text;

  blueutil  = "${pkgs.blueutil}/bin/blueutil";
  sas       = "${pkgs.switchaudio-osx}/bin/SwitchAudioSource";
  jq        = "${pkgs.jq}/bin/jq";
  tailscale = "/usr/local/bin/tailscale"; # Tailscale.app（App Store 版）が置く CLI

  # Wi-Fi: 周囲のネットワークをスキャン（CoreWLAN）。同じ名前は電波の強いものだけ、強い順
  #   出力: <SSID> US <RSSI> US <1 = 鍵なし / 0 = 鍵あり> US <チャンネル>（US = \x1f）
  wifiScan = pkgs.writeText "sketchybar-wifi-scan.js" ''
    $.NSBundle.bundleWithPath("/System/Library/Frameworks/CoreWLAN.framework").load;
    const itf = $.NSClassFromString("CWWiFiClient").sharedWiFiClient.interface;
    const nets = itf.scanForNetworksWithNameError($(), Ref());
    const best = {};
    if (nets && !nets.isNil()) {
      for (const n of nets.allObjects.js) {
        if (n.ssid.isNil()) continue;
        const ssid = n.ssid.js, rssi = n.rssiValue;
        if (!ssid || (best[ssid] && best[ssid].rssi >= rssi)) continue;
        best[ssid] = { rssi: rssi, open: n.supportsSecurity(0) ? 1 : 0, ch: n.wlanChannel.channelNumber };
      }
    }
    Object.keys(best).sort((a, b) => best[b].rssi - best[a].rssi)
      .map(k => [k, best[k].rssi, best[k].open, best[k].ch].join("\x1f")).join("\n");
  '';

  # Wi-Fi: 今の接続の情報。名前は位置情報の保護で取れないことが多いので、チャンネルと電波の強さも出す
  #   出力: <SSID（取れなければ空）> US <チャンネル> US <RSSI>
  wifiSsid = pkgs.writeText "sketchybar-wifi-ssid.js" ''
    $.NSBundle.bundleWithPath("/System/Library/Frameworks/CoreWLAN.framework").load;
    const i = $.NSClassFromString("CWWiFiClient").sharedWiFiClient.interface;
    [i.ssid.isNil() ? "" : i.ssid.js, i.wlanChannel.isNil() ? "" : i.wlanChannel.channelNumber, i.rssiValue].join("\x1f");
  '';

  # カメラ: 接続されているカメラと、ほかのアプリが使用中か（AVFoundation）
  #   出力: <カメラ名> US <1 = 使用中 / 0>
  cameraList = pkgs.writeText "sketchybar-cameras.js" ''
    $.NSBundle.bundleWithPath("/System/Library/Frameworks/AVFoundation.framework").load;
    $.NSClassFromString("AVCaptureDevice").devicesWithMediaType("vide").js
      .map(d => [d.localizedName.js, d.isInUseByAnotherApplication ? 1 : 0].join("\x1f")).join("\n");
  '';

  # メニューの行にマウスが乗ったら背景を付ける
  hover = plugin "hover" ''
    case "$SENDER" in
      mouse.entered) sketchybar --set "$NAME" background.drawing=on ;;
      mouse.exited)  sketchybar --set "$NAME" background.drawing=off ;;
    esac
  '';

  # ── 共通関数（各プラグインが読み込む）──────────────────────────────────── #
  # メニュー（ポップアップ）は開くたびに中身を作り直し、最新の状態を表示する。
  # 項目名は「<親>.dyn.<名前>」。クリック時の操作は $ACTION（action スクリプト）に渡す。
  lib = pkgs.writeText "sketchybar-lib.sh" ''
    FG=0xffc0caf5; SUB=0xff9aa5ce; DIM=0xff565f89; ACCENT=0xff7aa2f7; GREEN=0xff9ece6a; RED=0xfff7768e
    POPUPS="apple clock notify input battery volume bluetooth wifi vpn camera"
    MONO="HackGen:Regular:13.0" # 全角 = 英数字 2 文字分の等幅（カレンダーの列を揃える）
    # 通知を「すべて消去」した時刻（Mac の日時 = 2001-01-01 からの秒数）。これより前の通知は表示しない
    NOTIFY_CLEARED="$HOME/Library/Caches/sketchybar-notify-cleared"
    WIFI_SCAN="$HOME/Library/Caches/sketchybar-wifi-scan" # 直近のスキャン結果
    CAL_STATE="''${TMPDIR:-/tmp}/sketchybar-cal-offset" # カレンダーで表示中の月（今月からのずれ）

    wifi_dev() { networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}'; }
    preferred_networks() { networksetup -listpreferredwirelessnetworks "$1" | tail -n +2 | sed 's/^[[:space:]]*//'; }
    wifi_scan() { osascript -l JavaScript ${wifiScan} 2>/dev/null; }
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
    cameras() { osascript -l JavaScript ${cameraList} 2>/dev/null; }
    vget() { osascript -e "$1 of (get volume settings)"; }
    ts_json() { ${tailscale} status --json 2>/dev/null; }
    # 集中モードの切り替え用ショートカット（名前が「集中モード: 」で始まるもの）
    focus_shortcuts() { shortcuts list 2>/dev/null | grep '^集中モード: '; }

    # 作ったメニュー項目（幅を揃える対象を探すため）と、クリックできる項目（ハイライトする）
    MENU_ROWS=(); CLICKABLE_ROWS=(); CENTER_ROWS=() # CENTER_ROWS: メニュー幅いっぱいで中央に寄せる行
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
      return 0
    }

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
      MENU_ROWS+=("$parent.dyn.$name")
      estimate "$label" 62 75 125
      [ $# -gt 0 ] && make_clickable "$parent.dyn.$name"
      return 0
    }

    # menu_text <親> <名前> <テキスト> [色] [操作 引数...]（等幅フォント・アイコンなし。カレンダー表示用）
    menu_text() {
      local parent="$1" name="$2" text="$3" color="''${4:-$FG}"; shift 3; [ $# -gt 0 ] && shift
      local style=(icon.drawing=off label="$text" label.font="$MONO" label.color="$color"
                   label.padding_left=12 label.padding_right=16)
      [ $# -gt 0 ] && style+=(click_script="$ACTION $*")
      BATCH+=(--add item "$parent.dyn.$name" popup."$parent" --set "$parent.dyn.$name" "''${style[@]}")
      MENU_ROWS+=("$parent.dyn.$name")
      estimate "$text" 40 70 135
      [ $# -gt 0 ] && make_clickable "$parent.dyn.$name"
      return 0
    }

    # menu_header <親> <名前> <見出し>
    menu_header() {
      BATCH+=(--add item "$1.dyn.$2" popup."$1" --set "$1.dyn.$2" icon.drawing=off
        label="$3" label.font="Hack Nerd Font:Bold:11.0" label.color=$ACCENT
        label.padding_left=10 padding_left=0)
      MENU_ROWS+=("$1.dyn.$2")
      estimate "$3" 24 65 110
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
      MENU_ROWS+=("$1.dyn.$2")
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
        mouse.exited.global)
          sketchybar --set "$NAME" popup.drawing=off
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

  # ── メニュー項目から呼ぶ操作 ──────────────────────────────────────────── #
  action = plugin "action" ''
    . ${lib}
    # メニュー内の操作（カレンダーの月送り）以外はメニューを閉じる
    case "$1" in cal-* | notify-clear) ;; *) close_all ;; esac
    pane() { open "x-apple.systempreferences:$1"; }
    refresh() { sleep "$1"; sketchybar --update; }

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
      # 電力モードの変更（引数: b / c と 0 / 1 / 2）。管理者のパスワードを macOS の画面で尋ねる
      power-mode)
        case "$2$3" in b0|b1|b2|c0|c1|c2) ;; *) exit 0 ;; esac
        osascript -e "do shell script \"/usr/bin/pmset -$2 powermode $3\" with administrator privileges" >/dev/null 2>&1
        refresh 0 ;;
      datetime-settings) pane com.apple.Date-Time-Settings.extension ;;
      notify-settings)   pane com.apple.Notifications-Settings.extension ;;
      keyboard-settings) pane com.apple.Keyboard-Settings.extension ;;

      # 入力ソース: キー操作を送る（sketchybar にアクセシビリティの許可が必要）
      ime-next) osascript -e 'tell application "System Events" to key code 49 using control down' ;;
      emoji)    osascript -e 'tell application "System Events" to key code 49 using {control down, command down}' ;;
      focus-settings)    pane com.apple.Focus-Settings.extension ;;
      shortcuts-app)     open -a Shortcuts ;;
      open-app)          open -b "$2" ;;
      # 通知を「すべて消去」: 今の時刻を記録して、メニューとベルの件数を作り直す（macOS 側の通知は残る）
      notify-clear)
        mkdir -p "$(dirname "$NOTIFY_CLEARED")"
        echo $(( $(date +%s) - 978307200 )) > "$NOTIFY_CLEARED"
        sketchybar --trigger menu_rebuild TARGET=notify
        sketchybar --trigger notify_update ;; # 通知をクリック → そのアプリを開く
      fda-settings)      open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" ;;

      # 集中モード: ショートカットを実行（引数は一覧での番号）
      focus-run) shortcuts run "$(focus_shortcuts | sed -n "$2p")" ;;

      # カレンダーの月送り（引数: 月数 / 0 = 今月）
      # メニューは作り直さず、月送りの行とカレンダーの画像だけ差し替える
      # （行を消して作り直すと、直後のクリックが古い行に向かい、別の見えない行が拾ってメニューが閉じる）
      cal-shift)
        off="$(cat "$CAL_STATE" 2>/dev/null || echo 0)"
        if [ "$2" = 0 ]; then off=0; else off=$((off + $2)); fi
        echo "$off" > "$CAL_STATE"
        if [ "$off" -ge 0 ]; then sign="+$off"; else sign="$off"; fi
        read -r y m < <(date -v1d -v"''${sign}m" '+%Y %-m')
        read -r nav grid < <(${calRender} "$y" "$m" "''${TMPDIR:-/tmp}/sketchybar-calendar" 2>/dev/null)
        [ -n "$grid" ] && sketchybar --set clock.dyn.cal.nav background.image="$nav" slider.percentage=0 \
                                     --set clock.dyn.cal.grid background.image="$grid" ;;

      # 通知センター: 隠れている標準メニューバーの時計をアクセシビリティ経由でクリックして開く
      # （sketchybar にアクセシビリティの許可が必要。失敗したら通知設定を開く）
      nc-open)
        osascript -e '
          tell application "System Events" to tell process "ControlCenter"
            repeat with mi in menu bar items of menu bar 1
              try
                if value of attribute "AXIdentifier" of mi is "com.apple.menuextra.clock" then
                  click mi
                  return
                end if
              end try
            end repeat
          end tell
          error "clock not found"' >/dev/null 2>&1 \
          || pane com.apple.Notifications-Settings.extension ;;

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

      # Wi-Fi（wifi-join の引数は登録済みネットワーク一覧での番号）
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
        if [ -n "$out" ]; then
          osascript - "$out" <<'AS' >/dev/null 2>&1
    on run argv
      display notification (item 1 of argv) with title "Wi-Fi に接続できませんでした"
    end run
    AS
        fi
        refresh 3 ;;
      camera-privacy) pane "com.apple.preference.security?Privacy_Camera" ;;
      wifi-join)
        dev="$(wifi_dev)"
        ssid="$(preferred_networks "$dev" | sed -n "$2p")"
        # 失敗したとき（パスワードが必要など）は何か出力されるので Wi-Fi 設定を開く
        [ -n "$(networksetup -setairportnetwork "$dev" "$ssid" 2>&1)" ] && pane com.apple.wifi-settings-extension
        refresh 3 ;;

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

  # 各プラグインの先頭: 操作スクリプトの場所を渡して共通関数を読み込む
  header = ''
    ACTION=${action}
    . ${lib}
  '';

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

  space = plugin "space" ''
    focused="''${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
    if [ "$1" = "$focused" ]; then
      sketchybar --set "$NAME" background.drawing=on label.color=0xff1a1b26
    else
      sketchybar --set "$NAME" background.drawing=off label.color=0xffc0caf5
    fi
  '';

  frontApp = plugin "front-app" ''
    if [ "$SENDER" = "front_app_switched" ]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
  '';

  # ── 時計 ──────────────────────────────────────────────────────────────── #
  # カレンダーの月送り行。行全体をスライダーにして画像（‹ 年月 ›）を敷き、クリック位置で分ける
  # （左 2 割 = 前の月 / 右 2 割 = 次の月 / 真ん中 = 今月）。スライダーは帯の外のクリックを無視するため
  calNav = plugin "cal-nav" ''
    [ "$SENDER" = "mouse.clicked" ] || exit 0
    if   [ "''${PERCENTAGE:-50}" -lt 20 ]; then exec ${action} cal-shift -1
    elif [ "''${PERCENTAGE:-50}" -gt 80 ]; then exec ${action} cal-shift 1
    else exec ${action} cal-shift 0; fi
  '';

  # カレンダーを画像で描く（pkgs/calendar/render.py。日曜・祝日は赤、土曜は青、今日は丸、予定は点）
  calRender = "${pkgs.python3.withPackages (ps: [ ps.pillow ])}/bin/python3 ${../pkgs/calendar/render.py}";

  # 時刻・月カレンダー・直近の予定をメニュー内に表示（外部アプリは開かない）
  icalBuddy = "/opt/homebrew/bin/icalBuddy"; # Homebrew の ical-buddy（modules/homebrew.nix）

  clock = plugin "clock" (header + ''
    weekday_ja() { case "$(date '+%u')" in 1) echo 月;; 2) echo 火;; 3) echo 水;; 4) echo 木;; 5) echo 金;; 6) echo 土;; 7) echo 日;; esac; }

    # 月カレンダー（月送りの行とカレンダー本体を画像で描いて並べる。幅 224）
    calendar() {
      local p=clock off sign y m nav grid
      off="$(cat "$CAL_STATE" 2>/dev/null || echo 0)"
      if [ "$off" -ge 0 ]; then sign="+$off"; else sign="$off"; fi
      read -r y m < <(date -v1d -v"''${sign}m" '+%Y %-m')
      read -r nav grid < <(${calRender} "$y" "$m" "''${TMPDIR:-/tmp}/sketchybar-calendar" 2>/dev/null)
      [ -n "$grid" ] || return 0

      # 画像は行の背景に敷く（スライダーの帯に敷くと、帯の「進んだ部分」にも同じ画像が描かれて二重になる）。
      # スライダーは透明にして、クリック位置を受け取るためだけに使う
      BATCH+=(--add slider "$p.dyn.cal.nav" popup."$p" 224
        --set "$p.dyn.cal.nav" icon.drawing=off label.drawing=off
          background.drawing=on background.color=0x00000000 background.height=30
          background.image="$nav" background.image.scale=0.5
          slider.percentage=0 slider.knob="" slider.highlight_color=0x00000000
          slider.background.drawing=on slider.background.color=0x00000000 slider.background.height=30
          script="${calNav}"
        --subscribe "$p.dyn.cal.nav" mouse.clicked
        --add item "$p.dyn.cal.grid" popup."$p"
        --set "$p.dyn.cal.grid" icon.drawing=off label.drawing=off width=224
          background.drawing=on background.color=0x00000000 background.height=178
          background.image="$grid" background.image.scale=0.5)
      MENU_ROWS+=("$p.dyn.cal.nav" "$p.dyn.cal.grid")
      [ "$MAX_WIDTH" -lt 232 ] && MAX_WIDTH=232
      return 0
    }

    # 今日から 1 週間の予定（カレンダー.app のデータを icalBuddy で読む）
    events() {
      local p=clock line i=0 LC_ALL=en_US.UTF-8
      menu_header $p h.ev "予定（7日間）"
      if [ ! -x ${icalBuddy} ]; then
        menu_item $p ev.none "󰃭" "ical-buddy が未インストールです"
        return
      fi
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        i=$((i + 1))
        [ "''${#line}" -gt 26 ] && line="''${line:0:26}…"
        menu_item $p "ev.$i" "󰃭" "$line"
      done < <(${icalBuddy} -n -nc -nrd -b "" -iep "datetime,title" -po "datetime,title" -ps "|  |" \
                 -df "%m/%d(%a)" -tf "%H:%M" -li 10 eventsToday+7 2>/dev/null)
      [ "$i" -eq 0 ] && menu_item $p ev.none "󰃭" "予定はありません"
    }

    build_menu() {
      local p=clock
      BATCH+=(--add item "$p.dyn.now" popup."$p" --set "$p.dyn.now" icon.drawing=off
        label="$(date '+%H:%M')" label.font="Hack Nerd Font:Bold:22.0" label.color=$FG
        label.padding_left=0 label.padding_right=0)
      MENU_ROWS+=("$p.dyn.now"); CENTER_ROWS+=("$p.dyn.now")
      calendar
      events
      menu_item $p dt "󰒓" "日付と時刻設定…" datetime-settings
      # カレンダーの画像（幅 224）をメニューの中央に置く
      local pad=$(( 4 + (MAX_WIDTH - 224) / 2 ))
      BATCH+=(--set "$p.dyn.cal.nav" padding_left=$pad --set "$p.dyn.cal.grid" padding_left=$pad)
    }

    # 開くたびに今月から表示
    [ "$SENDER" = "mouse.clicked" ] && echo 0 > "$CAL_STATE"
    handle_popup
    sketchybar --set "$NAME" label="$(date '+%m/%d')($(weekday_ja)) $(date '+%H:%M')"
  '');

  # ── 入力ソース ────────────────────────────────────────────────────────── #
  input = plugin "input" (header + ''
    # 入力ソースの ID → バーに出す 1 文字 / メニューに出す名前
    short_name() {
      case "$1" in
        *Katakana | *katakana)         echo カ ;;
        *HalfWidthKana | *hankaku)     echo ｶ ;;
        *FullWidthRoman | *eisu)       echo Ａ ;;
        *Japanese* | *hiragana)        echo あ ;;
        *)                             echo A ;;
      esac
    }
    long_name() {
      case "$1" in
        com.apple.inputmethod.Japanese)          echo "日本語 - ローマ字入力" ;;
        com.apple.inputmethod.Japanese.Katakana) echo "日本語 - カタカナ" ;;
        net.mtgto.inputmethod.macSKK*)           echo "macSKK（''${1##*.}）" ;;
        *.*)                                     echo "''${1##*.}" ;;
        *)                                       echo "$1" ;;
      esac
    }
    # HIToolbox の設定から入力ソースの ID（Input Mode / キーボードレイアウト名）を取り出す
    sources() {
      defaults read com.apple.HIToolbox "$1" 2>/dev/null | awk -F' = ' '
        /^ *"(Input Mode|KeyboardLayout Name)" = / { v = $2; gsub(/[";]/, "", v); if (!seen[v]++) print v }'
    }
    current() { sources AppleSelectedInputSources | tail -1; }

    build_menu() {
      local p=input cur src i=0 icon
      cur="$(current)"
      menu_header $p h.src "入力ソース"
      while IFS= read -r src; do
        i=$((i + 1))
        if [ "$src" = "$cur" ]; then icon="󰐾"; else icon="󰐽"; fi
        menu_item $p "src.$i" "$icon" "$(long_name "$src")"
      done < <(sources AppleEnabledInputSources)
      menu_item $p next     "󰌌" "次の入力ソースへ（⌃Space）" ime-next
      menu_item $p emoji    "☺"    "絵文字と記号を表示"         emoji
      menu_item $p settings "󰒓"      "キーボード設定…"            keyboard-settings
    }
    handle_popup

    [ "$SENDER" = "input_change" ] && sleep 0.2 # 設定ファイルへの反映を待つ
    sketchybar --set "$NAME" label="$(short_name "$(current)")"
  '');

  # ── 通知 ──────────────────────────────────────────────────────────────── #
  # 通知の一覧: 通知センターのデータベースを読み、1 行 1 通知で出力する
  #   出力: <Bundle ID> US <アプリ名> US <日時> US <タイトル> US <本文>（US = \x1f）
  #   読めない（フルディスクアクセスがない）ときは "ERROR" だけを出力
  notifList = pkgs.writeScript "sketchybar-notifications" ''
    #!${pkgs.python3}/bin/python3
    import os, sqlite3, plistlib, subprocess, sys
    from datetime import datetime, timedelta, timezone

    DB = os.path.expanduser("~/Library/Group Containers/group.com.apple.usernoted/db2/db")
    EPOCH = datetime(2001, 1, 1, tzinfo=timezone.utc)  # Mac の日時の起点
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    since = float(sys.argv[2]) if len(sys.argv) > 2 else 0  # これより後に届いた通知だけ

    try:
        con = sqlite3.connect("file:" + DB + "?mode=ro", uri=True)
        rows = con.execute(
            "SELECT a.identifier, r.data, r.delivered_date FROM record r"
            " JOIN app a ON a.app_id = r.app_id"
            " WHERE r.delivered_date > ?"
            " ORDER BY r.delivered_date DESC LIMIT ?", (since, limit)).fetchall()
    except Exception:
        print("ERROR")
        sys.exit(0)

    names = {}

    def app_name(bid):
        if bid not in names:
            name = bid.rsplit(".", 1)[-1]
            try:
                path = subprocess.run(
                    ["mdfind", "kMDItemCFBundleIdentifier == '" + bid + "'"],
                    capture_output=True, text=True, timeout=2).stdout.split("\n")[0]
                if path.endswith(".app"):
                    name = os.path.basename(path)[:-4]
            except Exception:
                pass
            names[bid] = name
        return names[bid]

    def clean(s):
        return " ".join(str(s or "").split())

    for bid, data, delivered in rows:
        try:
            req = plistlib.loads(data).get("req", {})
        except Exception:
            req = {}
        when = (EPOCH + timedelta(seconds=delivered or 0)).astimezone()
        title = clean(req.get("titl")) or clean(req.get("subt"))
        print("\x1f".join([bid, app_name(bid), when.strftime("%m/%d %H:%M"), title, clean(req.get("body"))]))
  '';

  # 通知の履歴・集中モードの状態は macOS が保護していて直接読めない。
  # 集中モードは「ショートカット」アプリ経由で扱う:
  #   - 「集中モード: 〜」という名前のショートカットをメニューに並べ、クリックで実行
  #   - 「集中モード状態」という名前のショートカット（現在の集中モードを取得して出力）があれば現在の状態を表示
  notify = plugin "notify" (header + ''
    notifications() { ${notifList} "$1" "$(cat "$NOTIFY_CLEARED" 2>/dev/null || echo 0)"; }

    # 最新の通知（クリックでそのアプリを開く）
    notification_list() {
      local p=notify i=0 bid app when title body text LC_ALL=en_US.UTF-8
      menu_header $p h.list "通知（最新 15 件）"
      while IFS=$'\x1f' read -r bid app when title body; do
        if [ "$bid" = ERROR ]; then
          menu_item $p n.err "" "表示にはフルディスクアクセスが必要です"
          menu_item $p n.fda "󰒓"  "フルディスクアクセスの設定…" fda-settings
          return
        fi
        i=$((i + 1))
        text="$app"
        [ -n "$title" ] && text="$text: $title"
        [ -n "$body" ] && text="$text — $body"
        # 長い通知は 40 文字で切る（幅の見積もりも切った後の文字で行うので、メニューが広がりすぎない）
        [ "''${#text}" -gt 40 ] && text="''${text:0:40}…"
        menu_item $p "n.$i" "" "$when  $text" open-app "$bid"
      done < <(notifications 15)
      if [ "$i" -eq 0 ]; then menu_item $p n.none "" "通知はありません"
      else menu_item $p n.clear "" "すべて消去" notify-clear; fi
    }

    build_menu() {
      local p=notify i=0 sc cur tmp
      notification_list
      menu_item $p nc "" "通知センターを開く" nc-open

      menu_header $p h.focus "集中モード"
      if shortcuts list 2>/dev/null | grep -qx '集中モード状態'; then
        tmp="$(mktemp)"
        shortcuts run '集中モード状態' --output-path "$tmp" >/dev/null 2>&1
        cur="$(head -1 "$tmp" 2>/dev/null)"; rm -f "$tmp"
        menu_item $p focus.state "" "現在: ''${cur:-オフ}"
      fi
      while IFS= read -r sc; do
        i=$((i + 1))
        menu_item $p "focus.$i" "" "''${sc#集中モード: }" focus-run "$i"
      done < <(focus_shortcuts)
      if [ "$i" -eq 0 ]; then
        # 切り替え用のショートカット（名前が「集中モード: 〜」）がまだない
        menu_item $p focus.none "" "切り替え用ショートカットがありません"
        menu_item $p focus.app  "" "ショートカットを開く" shortcuts-app
      fi
      menu_item $p focus  "󰒓" "集中モード設定…" focus-settings
      menu_item $p notify "󰒓" "通知設定…"       notify-settings
    }
    handle_popup

    # ベルの右上に、消去後に届いた通知の件数をバッジで表示（0 件・読めないときは非表示）
    count="$(notifications 99 | grep -vcx ERROR)"
    if [ "$count" -gt 0 ]; then
      [ "$count" -gt 9 ] && count="9+"
      sketchybar --set "$NAME" label="$count" label.drawing=on icon.color=$ACCENT
    else
      sketchybar --set "$NAME" label.drawing=off icon.color=$FG
    fi
  '');

  # ── バッテリー ────────────────────────────────────────────────────────── #
  battery = plugin "battery" (header + ''
    # 電力モード（pmset の powermode: 0 = 自動 / 1 = 低電力 / 2 = 高出力）を選ぶ行
    # power_modes <b = バッテリー | c = 電源アダプタ> <見出し>
    power_modes() {
      local section cur m icon label
      if [ "$1" = b ]; then section="Battery Power"; else section="AC Power"; fi
      cur="$(pmset -g custom | awk -v s="$section:" '$0 == s {f = 1; next} /^[A-Z]/ {f = 0} f && $1 == "powermode" {print $2}')"
      menu_header battery "h.pm$1" "$2"
      for m in 0 1 2; do
        if [ "$m" = "''${cur:-0}" ]; then icon="󰐾"; else icon="󰐽"; fi
        case "$m" in 0) label="自動" ;; 1) label="低電力" ;; 2) label="高出力" ;; esac
        menu_item battery "pm$1.$m" "$icon" "$label" power-mode "$1" "$m"
      done
    }

    build_menu() {
      local p=battery info pct src remain lpm
      info="$(pmset -g batt)"
      pct="$(echo "$info" | grep -Eo '[0-9]+%' | head -1)"
      if echo "$info" | grep -q 'AC Power'; then src="電源アダプタ"; else src="バッテリー"; fi
      remain="$(echo "$info" | grep -Eo '[0-9]+:[0-9]+ remaining' | cut -d' ' -f1)"
      if echo "$info" | grep -q 'charged'; then remain="充電完了"
      elif [ -z "$remain" ]; then remain="計算中"
      elif echo "$info" | grep -q 'AC Power'; then remain="満充電まで $remain"
      else remain="残り $remain"; fi
      menu_item $p pct    "󰁹" "残量 ''${pct:-?}"
      menu_item $p src    "󰂄"  "電源: $src"
      menu_item $p remain "󰥔"    "$remain"
      power_modes b "電力モード（バッテリー）"
      power_modes c "電力モード（電源アダプタ）"
      menu_item $p activity "󰄪" "アクティビティモニタ" activity
      menu_item $p settings "󰒓"   "バッテリー設定…"      battery-settings
    }
    handle_popup

    info="$(pmset -g batt)"
    pct="$(echo "$info" | grep -Eo '[0-9]+%' | tr -d '%')"
    [ -z "$pct" ] && exit 0
    if echo "$info" | grep -q 'AC Power'; then icon="󰂄"
    elif [ "$pct" -ge 80 ]; then icon="󰁹"
    elif [ "$pct" -ge 50 ]; then icon="󰁿"
    elif [ "$pct" -ge 20 ]; then icon="󰁻"
    else icon="󰁺"; fi
    sketchybar --set "$NAME" icon="$icon" label="''${pct}%"
  '');

  # ── 音量 ──────────────────────────────────────────────────────────────── #
  # メニュー内のスライダー（出力 / 入力の音量）
  volumeSlider = plugin "volume-slider" ''
    [ "$SENDER" = "mouse.clicked" ] || exit 0
    case "$NAME" in
      *.out) osascript -e "set volume output volume $PERCENTAGE" ;;
      *.in)  osascript -e "set volume input volume $PERCENTAGE" ;;
    esac
    sketchybar --set "$NAME" slider.percentage="$PERCENTAGE" label="$PERCENTAGE%"
  '';

  volume = plugin "volume" (header + ''
    # 出力 / 入力デバイスの一覧（現在のものに印）
    device_list() {
      local p=volume type="$1" cur dev i=0 icon
      cur="$(${sas} -c -t "$type")"
      while IFS= read -r dev; do
        i=$((i + 1))
        if [ "$dev" = "$cur" ]; then icon="󰐾"; else icon="󰐽"; fi
        menu_item $p "$type.$i" "$icon" "$dev" "audio-$([ "$type" = output ] && echo out || echo in)" "$i"
      done < <(${sas} -a -t "$type")
    }
    build_menu() {
      local p=volume vol invol
      vol="$(vget 'output volume')"; invol="$(vget 'input volume')"
      menu_header $p h.out "出力"
      menu_slider $p slider.out "󰓃" "''${vol:-0}" "${volumeSlider}"
      if [ "$(vget 'output muted')" = true ]; then menu_item $p mute "󰖁" "ミュートを解除" mute
      else menu_item $p mute "󰖁" "ミュート" mute; fi
      device_list output
      menu_header $p h.in "入力"
      menu_slider $p slider.in "󰍬" "''${invol:-0}" "${volumeSlider}"
      device_list input
      menu_item $p settings "󰒓" "サウンド設定…" sound-settings
    }
    handle_popup

    # スクロールで音量調整
    if [ "$SENDER" = "mouse.scrolled" ]; then
      new=$(( $(vget 'output volume') + SCROLL_DELTA * 3 ))
      [ "$new" -lt 0 ] && new=0
      [ "$new" -gt 100 ] && new=100
      osascript -e "set volume output volume $new"
    fi
    if [ "$SENDER" = "volume_change" ]; then vol="$INFO"; else vol="$(vget 'output volume')"; fi
    case "$vol" in "" | *[!0-9]*) vol=0 ;; esac # 出力先によっては取得できない
    if [ "$(vget 'output muted')" = true ] || [ "$vol" -eq 0 ]; then icon="󰖁"
    elif [ "$vol" -ge 60 ]; then icon="󰕾"
    else icon="󰖀"; fi
    sketchybar --set "$NAME" icon="$icon" label="''${vol}%"
    sketchybar --set volume.dyn.slider.out slider.percentage="$vol" label="$vol%" >/dev/null 2>&1
  '');

  # ── Bluetooth ─────────────────────────────────────────────────────────── #
  bluetooth = plugin "bluetooth" (header + ''
    build_menu() {
      local p=bluetooth line addr name i=0
      if [ "$(${blueutil} -p)" = 1 ]; then
        menu_item $p power "󰐥" "Bluetooth: オン（クリックでオフ）" bt-power 0
        menu_header $p h.dev "デバイス（クリックで接続 / 切断）"
        while IFS= read -r line; do
          addr="$(printf '%s' "$line" | sed -n 's/^address: \([^,]*\),.*/\1/p')"
          name="$(printf '%s' "$line" | sed -n 's/.*name: "\([^"]*\)".*/\1/p')"
          [ -z "$addr" ] && continue
          i=$((i + 1))
          if printf '%s' "$line" | grep -q ', connected'; then
            menu_item $p "dev.$i" "󰂱" "''${name:-$addr}（接続中）" bt-disconnect "$addr"
          else
            menu_item $p "dev.$i" "󰂯" "''${name:-$addr}" bt-connect "$addr"
          fi
        done < <(${blueutil} --paired 2>/dev/null)
        [ "$i" -eq 0 ] && menu_item $p none "󰂯" "登録済みのデバイスはありません"
      else
        menu_item $p power "󰐥" "Bluetooth: オフ（クリックでオン）" bt-power 1
      fi
      menu_item $p settings "󰒓" "Bluetooth 設定…" bt-settings
    }
    handle_popup

    if [ "$(${blueutil} -p)" = 1 ]; then
      if [ -n "$(${blueutil} --connected 2>/dev/null)" ]; then icon="󰂱"; color=$ACCENT
      else icon="󰂯"; color=$FG; fi
    else
      icon="󰂲"; color=$DIM
    fi
    sketchybar --set "$NAME" icon="$icon" icon.color="$color"
  '');

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
        wifi_scan > "$tmp" && [ -s "$tmp" ] && mkdir -p "$(dirname "$WIFI_SCAN")" && mv "$tmp" "$WIFI_SCAN"
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

  # ── CPU に合わせて走る猫（RunCat 風・絵はオリジナル）。ノッチのすぐ右 ────── #
  # 使用率を約 1 秒ごとに測り、コマの間隔を 0.2 秒（暇）〜 0.03 秒（全開）で変える。右に使用率を表示
  runcatFrames = pkgs.callPackage ../pkgs/runcat { };
  runcat = plugin "runcat" ''
    pidfile="''${TMPDIR:-/tmp}/sketchybar-runcat.pid"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then exit 0; fi
    (
      ncpu="$(sysctl -n hw.ncpu)"; i=0; t=0; delay=0.2
      while sketchybar --query runcat >/dev/null 2>&1; do
        if [ "$t" -le 0 ]; then
          cpu="$(ps -A -o %cpu= | awk -v n="$ncpu" '{ s += $1 } END { c = s / n; if (c > 100) c = 100; printf "%d", c }')"
          delay="$(awk -v c="$cpu" 'BEGIN { printf "%.3f", 0.2 - c * 0.0017 }')"
          sketchybar --set runcat label="$cpu%"
          t="$(awk -v d="$delay" 'BEGIN { printf "%d", 1 / d }')" # 約 1 秒分のコマ数
        fi
        sketchybar --set runcat icon.background.image="${runcatFrames}/frame-$i.png"
        i=$(( (i + 1) % 5 )); t=$(( t - 1 ))
        sleep "$delay"
      done
    ) >/dev/null 2>&1 &
    echo $! > "$pidfile"
    disown
  '';

  # ── カメラ（使用中だけバーに表示）──────────────────────────────────────── #
  camera = plugin "camera" (header + ''
    build_menu() {
      local p=camera name used i=0
      menu_header $p h.cam "カメラ"
      while IFS=$'\x1f' read -r name used; do
        [ -z "$name" ] && continue
        i=$((i + 1))
        if [ "$used" = 1 ]; then menu_item $p "cam.$i" "󰕧" "$name（使用中）"
        else menu_item $p "cam.$i" "󰕨" "$name"; fi
      done < <(cameras)
      menu_item $p privacy "󰌾" "カメラを使えるアプリ…" camera-privacy
    }
    handle_popup

    if cameras | cut -d$'\x1f' -f2 | grep -qx 1; then
      sketchybar --set "$NAME" drawing=on
    else
      sketchybar --set "$NAME" drawing=off popup.drawing=off
    fi
  '');

  # ── VPN（Tailscale とシステムの VPN 設定）──────────────────────────────── #
  vpn = plugin "vpn" (header + ''
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
          Connected)  menu_item $p "vpn.$i" "󰖂" "$name（接続中）" vpn-stop "$id" ;;
          Connecting) menu_item $p "vpn.$i" "󰖂" "$name（接続処理中）" vpn-stop "$id" ;;
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
in
{
  # ── 上端クリックのガード ──────────────────────────────────────────────── #
  # macOS は画面の一番上の行と上の角のクリックを、sketchybar で覆っていても標準メニューバーに渡す。
  # クリック位置を少し内側に移して sketchybar に届ける（pkgs/menubar-click-guard）。
  # 初回はアクセシビリティの許可が必要（許可がないと起動に失敗し、30 秒ごとに再試行する）。
  launchd.user.agents.menubar-click-guard.serviceConfig = {
    ProgramArguments = [ "${pkgs.callPackage ../pkgs/menubar-click-guard { }}/bin/menubar-click-guard" ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardErrorPath = "/tmp/menubar-click-guard.log";
  };

  # ── Jankyborders（ウィンドウ枠線）────────────────────────────────────────── #
  services.jankyborders = {
    enable         = true;
    style          = "round";
    width          = 2.0; # AeroSpace の隙間 3 に収まる太さ
    hidpi          = true;
    active_color   = "0xc0ff00f2";
    inactive_color = "0xff0080ff";
  };

  # ── Sketchybar（ステータスバー）──────────────────────────────────────────── #
  # aerospace CLI は Homebrew cask 提供（/opt/homebrew/bin は systemPath 経由で PATH に入る）
  # 各項目はクリックでメニューを開く（中身は modules/desktop.nix の各プラグインの build_menu）
  services.sketchybar = {
    enable = true;
    # topmost=on のバーは macOS のメニューバーアイコン（時計・コントロールセンター等）と同じ
    # ステータスレベルに置かれ、隠れた標準メニューバーが出てくると端のクリックがそちらに抜ける。
    # バーをポップアップ（PopUpMenu レベル）のすぐ下まで上げて、常に手前でクリックを受けるようにする。
    package = pkgs.sketchybar.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/bar_manager.c \
          --replace-fail "bar_manager->window_level = kCGStatusWindowLevel;" \
                         "bar_manager->window_level = kCGPopUpMenuWindowLevel - 1;"
      '';
    });
    config = ''
      # topmost=on: マウスを上端に寄せて出てくる macOS のメニューバーをバーで覆い隠す
      # height=33: 標準メニューバーと同じ高さ（低いと下端の 1px にクリックが抜ける）
      # color は不透明（常に表示している標準メニューバーが透けないように）
      sketchybar --bar position=top height=33 color=0xff1a1b26 \
        padding_left=12 padding_right=12 topmost=on

      sketchybar --default \
        icon.font="Hack Nerd Font:Bold:15.0" \
        label.font="Hack Nerd Font:Bold:13.0" \
        icon.color=0xffc0caf5 label.color=0xffc0caf5 \
        padding_left=4 padding_right=4 \
        icon.padding_left=4 icon.padding_right=4 \
        label.padding_left=4 label.padding_right=4

      # メニュー（ポップアップ）の見た目
      # y_offset=0: バーとメニューの間にすき間があると、マウスがそこを通るときに
      #   「バーからもメニューからも出た」扱いになってメニューが閉じてしまう
      POPUP="popup.background.color=0xf01a1b26 popup.background.corner_radius=8 \
        popup.background.border_width=1 popup.background.border_color=0xff414868 \
        popup.blur_radius=30 popup.y_offset=0"
      MENU="mouse.clicked mouse.exited.global"

      # ── 左: Apple メニュー ──
      sketchybar --add item apple left \
        --subscribe apple $MENU \
        --set apple icon="" icon.font="Hack Nerd Font:Bold:17.0" label.drawing=off \
          padding_right=8 script="${apple}" popup.align=left $POPUP

      # ── 左: AeroSpace ワークスペース 1〜9 ──
      sketchybar --add event aerospace_workspace_change
      for sid in 1 2 3 4 5 6 7 8 9; do
        sketchybar --add item "space.$sid" left \
          --subscribe "space.$sid" aerospace_workspace_change \
          --set "space.$sid" \
            label="$sid" icon.drawing=off \
            background.color=0xff7aa2f7 background.corner_radius=5 \
            background.height=22 background.drawing=off \
            click_script="aerospace workspace $sid" \
            script="${space} $sid"
      done

      # ── 左: 前面アプリ ──
      sketchybar --add item front_app left \
        --subscribe front_app front_app_switched \
        --set front_app icon.drawing=off label.color=0xff9ece6a script="${frontApp}"

      # メニューを開いたまま中身を作り直すためのイベント（カレンダーの月送り）
      sketchybar --add event menu_rebuild
      sketchybar --add event notify_update # 通知の件数を更新

      # ── 右（右端から）: 通知 / 時計 / バッテリー / 音量 / 入力ソース / Bluetooth / ネットワーク / VPN ──
      sketchybar --add item notify right \
        --subscribe notify menu_rebuild notify_update $MENU \
        --set notify icon="󰂚" label.drawing=off update_freq=60 script="${notify}" \
          label.font="Hack Nerd Font:Bold:9.0" label.color=0xffffffff label.y_offset=6 \
          icon.padding_right=0 label.padding_left=3 label.padding_right=3 \
          label.background.drawing=on label.background.color=0xfff7768e \
          label.background.corner_radius=6 label.background.height=12 \
          popup.align=right $POPUP

      sketchybar --add item clock right \
        --subscribe clock menu_rebuild $MENU \
        --set clock icon.drawing=off update_freq=10 script="${clock}" popup.align=right $POPUP

      sketchybar --add item battery right \
        --subscribe battery system_woke power_source_change $MENU \
        --set battery update_freq=120 script="${battery}" popup.align=right $POPUP

      sketchybar --add item volume right \
        --subscribe volume volume_change mouse.scrolled $MENU \
        --set volume script="${volume}" popup.align=right $POPUP

      # CPU に合わせて走る猫（ノッチのすぐ右 = position e。88x48 px の絵を 0.3 倍 ≒ 26x14 で表示）
      # 使用率の数字は幅を固定して、桁が変わっても位置がずれないようにする
      sketchybar --add item runcat e \
        --set runcat icon="" icon.width=28 icon.background.drawing=on \
          icon.background.image="${runcatFrames}/frame-0.png" icon.background.image.scale=0.3 \
          label="0%" label.font="Hack Nerd Font:Bold:11.0" label.color=0xff9aa5ce \
          label.width=34 label.padding_left=2 \
          script="${runcat}"

      # 入力ソースの切り替えを macOS の通知で受け取る
      sketchybar --add event input_change AppleSelectedInputSourcesChangedNotification
      sketchybar --add item input right \
        --subscribe input input_change front_app_switched $MENU \
        --set input icon.drawing=off label.font="Hack Nerd Font:Bold:14.0" \
          script="${input}" popup.align=right $POPUP

      sketchybar --add item bluetooth right \
        --subscribe bluetooth system_woke $MENU \
        --set bluetooth label.drawing=off update_freq=30 script="${bluetooth}" \
          popup.align=right $POPUP

      sketchybar --add item wifi right \
        --subscribe wifi wifi_change system_woke menu_rebuild $MENU \
        --set wifi update_freq=30 script="${wifi}" popup.align=right $POPUP

      sketchybar --add item camera right \
        --subscribe camera system_woke $MENU \
        --set camera icon="󰕧" icon.color=0xff9ece6a label.drawing=off drawing=off \
          update_freq=3 script="${camera}" popup.align=right $POPUP

      sketchybar --add item vpn right \
        --subscribe vpn system_woke $MENU \
        --set vpn icon="󰖂" label.drawing=off update_freq=30 script="${vpn}" \
          popup.align=right $POPUP

      sketchybar --update
    '';
  };
}
