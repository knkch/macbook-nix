# sketchybar（ステータスバー）と、集中モードの切り替え用ショートカット
#   shared.nix  共通部品（プラグインの作り方・集中モードの一覧・外部コマンド・カレンダーの道具）
#   lib.nix     各プラグインが読み込む共通関数（色・メニューの作り方・集中モード・カレンダー）
#   action.nix  メニューの行を押したときの操作
#   plugins/    バーの各項目（1 ファイル 1 項目。クリックで開くメニューは build_menu）
#   doctor.nix  sketchybar-doctor（macOS の更新で壊れていないかの点検）
{ config, pkgs, user, ... }:
let
  # 各ファイルは ctx（全部の部品をまとめたもの）を受け取って自分の部品を返し、ほかの部品は ctx から使う
  ctx = pkgs.lib.fix (self:
    { inherit pkgs; }
    // import ./shared.nix self
    // import ./lib.nix self
    // import ./action.nix self
    // import ./doctor.nix self
    // pkgs.lib.foldl' (acc: name: acc // import (./plugins + "/${name}.nix") self) { } [
      "apple" "space" "front-app" "clock" "input" "notify" "battery" "volume"
      "bluetooth" "wifi" "music" "runcat" "camera" "vpn"
    ]);
  inherit (ctx) doctor focusShortcuts action apple space frontApp notify clock battery volume music runcatFrames runcat input bluetooth wifi camera vpn;
in
{
  # ── 集中モードの切り替え用ショートカット ──────────────────────────────── #
  # `focus-shortcuts` で足りないものだけ取り込む（何回実行しても同じ結果）。
  # rebuild のたびに確認だけ行い、足りなければ知らせる（取り込み画面は勝手に開かない）
  environment.systemPackages = [ focusShortcuts doctor ];
  home-manager.users.${user} = { lib, ... }: {
    home.activation.focusShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # 失敗しても rebuild を止めない（activation は set -e で動く）。一覧を読めないとき（2）は黙る
      rc=0; ${focusShortcuts}/bin/focus-shortcuts --check >/dev/null 2>&1 || rc=$?
      if [ "$rc" -eq 1 ]; then
        echo "集中モードの切り替え用ショートカットが足りません。focus-shortcuts を実行してください" >&2
      fi
    '';
  };

  # ── Sketchybar（ステータスバー）──────────────────────────────────────────── #
  # aerospace CLI は Homebrew cask 提供（/opt/homebrew/bin は systemPath 経由で PATH に入る）
  # 各項目はクリックでメニューを開く（中身は plugins/ の各ファイルの build_menu）
  # ── 保護領域の読み取り（protected-reader）──────────────────────────────── #
  # 通知の履歴と集中モードの状態は macOS の保護領域にある。フルディスクアクセスはこの常駐プログラムだけに与え、
  # sketchybar には与えない（sketchybar は外からのコマンドで任意のスクリプトを実行できるため）。
  # 書き出し先: ~/Library/Caches/sketchybar-protected（自分だけが読める）。pkgs/protected-reader
  launchd.user.agents.protected-reader.serviceConfig = {
    ProgramArguments = [
      "${pkgs.callPackage ../../pkgs/protected-reader { }}/bin/protected-reader"
      "${config.services.sketchybar.package}/bin/sketchybar"
      "${config.users.users.${user}.home}/Library/Caches/sketchybar-protected"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardErrorPath = "/tmp/protected-reader.log";
  };

  # ── アクセシビリティの操作（ax-agent）──────────────────────────────────── #
  # アプリのメニューを開く・通知センターを開く・カメラの使用中の判定・入力ソースのキー操作には
  # アクセシビリティが要る。許可はこの常駐プログラムだけに与え、sketchybar には与えない（理由は上と同じ）。
  # sketchybar は ~/Library/Caches/sketchybar-ax/sock（自分だけが使える）に頼む。できる操作は固定。pkgs/ax-agent
  launchd.user.agents.ax-agent.serviceConfig = {
    ProgramArguments = [
      "${pkgs.callPackage ../../pkgs/ax-agent { }}/bin/ax-agent"
      "${config.users.users.${user}.home}/Library/Caches/sketchybar-ax"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardErrorPath = "/tmp/ax-agent.log";
  };

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
      # notch_width: 内蔵画面のノッチの実際の幅（185）。ノッチの左右の項目（猫・曲名）をノッチに寄せる
      sketchybar --bar position=top height=33 color=0xff1a1b26 \
        padding_left=12 padding_right=12 topmost=on \
        notch_width=186

      sketchybar --default \
        icon.font="Hack Nerd Font:Bold:15.0" \
        label.font="Hack Nerd Font:Bold:13.0" \
        icon.color=0xffc0caf5 label.color=0xffc0caf5 \
        padding_left=4 padding_right=4 \
        icon.padding_left=4 icon.padding_right=4 \
        label.padding_left=4 label.padding_right=4

      # メニュー（ポップアップ）の見た目。背景は少し透かしてぼかす（すりガラス風。バー本体は不透明）
      # y_offset=0: バーとメニューの間にすき間があると、マウスがそこを通るときに
      #   「バーからもメニューからも出た」扱いになってメニューが閉じてしまう
      POPUP="popup.background.color=0xb01a1b26 popup.background.corner_radius=8 \
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
        --subscribe front_app front_app_switched $MENU \
        --set front_app icon.drawing=off label.color=0xff9ece6a script="${frontApp}" $POPUP

      # メニューを開いたまま中身を作り直すためのイベント（Wi-Fi のスキャン後・通知の消去後）
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
        --subscribe clock $MENU \
        --set clock icon.drawing=off update_freq=10 script="${clock}" popup.align=right $POPUP \
          popup.height=26 # 行の最低の高さ（既定はバーの高さ 33。カレンダーの週の行を詰める）

      sketchybar --add item battery right \
        --subscribe battery system_woke power_source_change $MENU \
        --set battery update_freq=120 script="${battery}" popup.align=right $POPUP

      sketchybar --add item volume right \
        --subscribe volume volume_change mouse.scrolled $MENU \
        --set volume script="${volume}" popup.align=right $POPUP

      # 再生中の曲（ノッチのすぐ左 = position q。長い曲名は 30 文字まで。停止中は「停止中」、mpd が動いていなければ「オフ」）
      sketchybar --add event music_update
      sketchybar --add item music q \
        --subscribe music music_update $MENU \
        --set music label.max_chars=30 label.font="Hack Nerd Font:Bold:12.0" \
          script="${music}" popup.align=center $POPUP

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

      # カメラ（使用中だけ表示）。押すと、使用中のカメラのビデオエフェクトのメニューを直接開く
      sketchybar --add item camera right \
        --subscribe camera system_woke \
        --set camera icon="󰕧" icon.color=0xff9ece6a drawing=off label.font="Hack Nerd Font:Bold:11.0" \
          update_freq=3 script="${camera}" click_script="${action} camera-effects"

      sketchybar --add item vpn right \
        --subscribe vpn system_woke $MENU \
        --set vpn icon="󰖂" label.drawing=off update_freq=30 script="${vpn}" \
          popup.align=right $POPUP

      sketchybar --update
    '';
  };
}
