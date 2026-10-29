ctx:
let
  inherit (ctx) header pkgs plugin;
in
rec {
  # ── 通知 ──────────────────────────────────────────────────────────────── #
  # 通知の一覧: protected-reader が書き出した通知（新しい順・最大 99 件）を読み、1 行 1 通知で出力する
  #   入力: <Bundle ID> US <届いた日時（2001-01-01 からの秒）> US <タイトル> US <本文>（US = \x1f）
  #   出力: <Bundle ID> US <アプリ名> US <日時> US <タイトル> US <本文>
  #   読めない（protected-reader が動いていない・フルディスクアクセスがない）ときは "ERROR" だけを出力
  notifList = pkgs.writeScript "sketchybar-notifications" ''
    #!${pkgs.python3}/bin/python3
    import os, subprocess, sys
    from datetime import datetime, timedelta, timezone

    CACHE = os.path.expanduser("~/Library/Caches/sketchybar-protected/notifications")
    EPOCH = datetime(2001, 1, 1, tzinfo=timezone.utc)  # Mac の日時の起点
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    since = float(sys.argv[2]) if len(sys.argv) > 2 else 0  # これより後に届いた通知だけ

    try:
        with open(CACHE, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        lines = ["ERROR"]
    if lines[:1] == ["ERROR"]:
        print("ERROR")
        sys.exit(0)
    rows = []
    for line in lines:
        bid, delivered, title, body = (line.split("\x1f") + ["", "", "", ""])[:4]
        try:
            delivered = float(delivered)
        except ValueError:
            continue
        if delivered > since:
            rows.append((bid, delivered, title, body))
    rows = rows[:limit]

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

    for bid, delivered, title, body in rows:
        when = (EPOCH + timedelta(seconds=delivered)).astimezone()
        print("\x1f".join([bid, app_name(bid), when.strftime("%m/%d %H:%M"), title, body]))
  '';

  # 通知の履歴・集中モードの状態は保護領域にあるので、protected-reader（フルディスクアクセスあり）が
  # ~/Library/Caches/sketchybar-protected に書き出したものを読む（sketchybar には強い権限を持たせない）。
  # 集中モードの切り替えは「ショートカット」アプリの「集中モード: <名前> オン / オフ」を実行する。
  notify = plugin "notify" (header + ''
    notifications() { ${notifList} "$1" "$(cat "$NOTIFY_CLEARED" 2>/dev/null || echo 0)"; }

    # 最新の通知（クリックでそのアプリを開く）
    notification_list() {
      local p=notify i=0 bid app when title body text LC_ALL=en_US.UTF-8
      menu_header $p h.list "通知（最新 15 件）"
      while IFS=$'\x1f' read -r bid app when title body; do
        if [ "$bid" = ERROR ]; then
          menu_item $p n.err "" "表示には protected-reader にフルディスクアクセスが必要です"
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
      local p=notify i=0 name
      notification_list
      menu_item $p nc "" "通知センターを開く" nc-open
      menu_item $p notify "󰒓" "通知設定…" notify-settings

      # 集中モード: 1 モード 1 行。オンのモードは ● と緑。押すとオン / オフを切り替える
      menu_header $p h.focus "集中モード（押すとオン / オフ）"
      while IFS= read -r name; do
        i=$((i + 1))
        menu_item $p "focus.$i" "○" "$name" focus-toggle "$i" "$name"
        ARGS=(); focus_row_args "$i" "$name"; BATCH+=("''${ARGS[@]}")
      done < <(focus_modes)
      # 切り替え用のショートカット（名前が「集中モード: 〜 オン / オフ」）がまだない
      [ "$i" -eq 0 ] && menu_item $p focus.none "" "切り替え用ショートカットがありません"
      # 集中モードを増やしたときに、切り替え用のショートカットを作れるように
      menu_item $p focus.app "" "ショートカットを追加…" shortcuts-app
      menu_item $p focus  "󰒓" "集中モード設定…" focus-settings
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
}
