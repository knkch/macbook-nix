ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── カメラ（使用中だけ表示。緑 + 「使用中」。押すとビデオエフェクト）──────────────────────────────────────── #
  camera = plugin "camera" (header + ''
    # カメラの使用状態は、コントロールセンターの表示（「…カメラを使用中です」）から判定する
    # （AVFoundation の isInUseByAnotherApplication は、sketchybar にカメラの許可がないと常に「未使用」を返すため）
    camera_in_use() {
      osascript - <<'AS' 2>/dev/null | grep -q -E 'カメラ|[Cc]amera'
    tell application "System Events" to tell process "ControlCenter"
      repeat with mi in menu bar items of menu bar 1
        try -- 識別名を持たない項目もあるので 1 つずつ
          if value of attribute "AXIdentifier" of mi is "com.apple.menuextra.controlcenter" then return description of mi
        end try
      end repeat
    end tell
    return ""
    AS
    }

    # 使用中だけ表示（緑のアイコン + 「使用中」）。使っていなければ隠す
    if camera_in_use; then
      sketchybar --set "$NAME" drawing=on icon.color=$GREEN label="使用中" label.color=$GREEN label.drawing=on
    else
      sketchybar --set "$NAME" drawing=off
    fi
  '');
}
