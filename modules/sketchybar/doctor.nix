# sketchybar-doctor: macOS の更新などで、sketchybar が頼っている仕組みが壊れていないかを点検するコマンド。
# sketchybar は macOS が公開していない仕組み（通知のデータベース・集中モードの状態ファイル・
# コントロールセンターの項目の識別子など）に頼っているので、更新のあとに実行して確かめる。
ctx:
let
  inherit (ctx) pkgs focusShortcuts tailscale;
in
{
  doctor = pkgs.writeShellScriptBin "sketchybar-doctor" ''
    set -u
    ok=0; ng=0; unknown=0
    pass()  { echo "  ✓ $1"; ok=$((ok + 1)); }
    fail()  { echo "  ✗ $1"; [ -n "''${2:-}" ] && echo "      → $2"; ng=$((ng + 1)); }
    maybe() { echo "  − $1"; [ -n "''${2:-}" ] && echo "      → $2"; unknown=$((unknown + 1)); }
    running() { launchctl print "gui/$(id -u)/$1" 2>/dev/null | grep -q 'state = running'; }
    CACHE="$HOME/Library/Caches/sketchybar-protected"

    echo "常駐プログラム"
    if pgrep -x sketchybar >/dev/null; then pass "sketchybar が動いている"
    else fail "sketchybar が動いていない" "launchctl kickstart -k gui/$(id -u)/org.nixos.sketchybar"; fi
    for a in protected-reader ax-agent menubar-click-guard; do
      if running "org.nixos.$a"; then pass "$a が動いている"
      else fail "$a が動いていない" "ログ: /tmp/$a.log（多くは、更新で場所が変わって許可の付け直しが必要）"; fi
    done

    echo "保護領域の読み取り（protected-reader）"
    if [ ! -f "$CACHE/notifications" ]; then
      fail "通知: 読み取り結果がない" "protected-reader が一度も動いていない"
    elif [ "$(head -1 "$CACHE/notifications")" = ERROR ]; then
      fail "通知: 読めない" "$(grep '通知を読めません' /tmp/protected-reader.log 2>/dev/null | tail -1)"
      echo "      → authorization denied / unable to open = protected-reader にフルディスクアクセスがない"
      echo "        no such table / no such column = macOS 側でデータベースの形式が変わった（pkgs/protected-reader/main.m）"
    else
      pass "通知: 読めている（最新 $(grep -c . "$CACHE/notifications") 件）"
    fi
    if [ -f "$CACHE/focus" ]; then
      on="$(tr '\n' ' ' < "$CACHE/focus" | sed 's/ $//')"
      pass "集中モードの状態: 読めている（オンのモード: ''${on:-なし}）"
      [ -z "$on" ] && echo "      → 集中モードをオンにしても「なし」のままなら、Assertions.json の形式が変わった可能性"
    else
      fail "集中モードの状態: 読み取り結果がない" "protected-reader が一度も動いていない"
    fi

    echo "アクセシビリティの操作（ax-agent。アプリのメニュー・通知センター・カメラの判定・入力ソース）"
    ax() { printf '%s\n' "$*" | /usr/bin/nc -U -w 2 "$HOME/Library/Caches/sketchybar-ax/sock" 2>/dev/null; }
    case "$(ax trusted)" in
      1) pass "ax-agent にアクセシビリティの許可がある"
         ids="$(ax extras)"
         for id in com.apple.menuextra.clock com.apple.menuextra.controlcenter; do
           if printf '%s\n' "$ids" | grep -qx "$id"; then pass "$id がある"
           else fail "$id が見つからない" "macOS の更新で識別子が変わった可能性（pkgs/ax-agent/main.m）"; fi
         done ;;
      0) fail "ax-agent にアクセシビリティの許可がない" "プライバシーとセキュリティ > アクセシビリティ に $(launchctl print "gui/$(id -u)/org.nixos.ax-agent" 2>/dev/null | awk '/program = /{print $3; exit}') を追加" ;;
      *) fail "ax-agent に頼めない" "ログ: /tmp/ax-agent.log" ;;
    esac

    echo "集中モードのショートカット"
    ${focusShortcuts}/bin/focus-shortcuts --check >/dev/null 2>&1
    case $? in
      0) pass "そろっている" ;;
      1) fail "足りない" "focus-shortcuts を実行" ;;
      *) maybe "確認できない" "ショートカットの一覧を読めない" ;;
    esac

    echo "外部コマンド"
    if [ -x /opt/homebrew/bin/icalBuddy ]; then pass "icalBuddy（カレンダーの祝日・予定の件数）"
    else fail "icalBuddy がない" "modules/homebrew.nix の ical-buddy → rebuild"; fi
    if [ -x ${tailscale} ]; then pass "Tailscale の CLI"
    else fail "Tailscale の CLI がない（${tailscale}）" "Tailscale アプリの設定で CLI を入れる"; fi

    echo
    echo "結果: 正常 $ok / 問題 $ng / 確認できない $unknown"
    [ "$ng" -eq 0 ]
  '';
}
