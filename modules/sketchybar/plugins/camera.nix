ctx:
let
  inherit (ctx) header plugin;
in
rec {
  # ── カメラ（使用中だけ表示。緑 + 「使用中」。押すとビデオエフェクト）──────────────────────────────────────── #
  camera = plugin "camera" (header + ''
    # カメラの使用状態は、コントロールセンターの表示（「…カメラを使用中です」）から判定する
    # （AVFoundation の isInUseByAnotherApplication は、sketchybar にカメラの許可がないと常に「未使用」を返すため）
    # （判定は ax-agent が行う。コントロールセンターの項目を読むのにアクセシビリティが必要なため）
    camera_in_use() { [ "$(ax camera)" = 1 ]; }

    # 使用中だけ表示（緑のアイコン + 「使用中」）。使っていなければ隠す
    if camera_in_use; then
      sketchybar --set "$NAME" drawing=on icon.color=$GREEN label="使用中" label.color=$GREEN label.drawing=on
    else
      sketchybar --set "$NAME" drawing=off
    fi
  '');
}
