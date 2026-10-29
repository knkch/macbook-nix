ctx:
let
  inherit (ctx) header plugin;
in
rec {
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
}
