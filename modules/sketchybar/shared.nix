# sketchybar の共通部品: プラグインの作り方・集中モードの一覧・外部コマンドのパス・JXA・カレンダーの道具・各プラグインの先頭
ctx:
let
  inherit (ctx) action pkgs shLib;
in
rec {
  # sketchybar のプラグイン（nix store に置くので相対パス問題が起きない）
  plugin = name: text: pkgs.writeShellScript "sketchybar-${name}" text;

  # ── 集中モード（通知メニューで切り替える）──────────────────────────────── #
  # ここに書いたモードごとに、切り替え用ショートカット「集中モード: <name> オン / オフ」を
  # focus-shortcuts コマンドで用意し、メニューではオン / オフの状態を表示する。
  #   name    = メニューとショートカットの名前
  #   id      = macOS の集中モードの識別子（今の状態を調べるのと、ショートカットの中身に使う）
  #   display = ショートカットアプリの「集中モードを設定」に表示される名前
  # モードはシステム設定 > 集中モード に追加しておく必要がある（ないモードは切り替えられない）。
  # 標準モードの識別子: 仕事 com.apple.focus.work / パーソナル com.apple.focus.personal-time /
  #   割り込みを減らす com.apple.focus.reduce-interruptions（詳しくは CLAUDE.md）
  focusModes = [
    { name = "おやすみ"; id = "com.apple.donotdisturb.mode.default"; display = "おやすみモード"; }
    { name = "睡眠";     id = "com.apple.sleep.sleep-mode";          display = "睡眠"; }
    { name = "仕事";     id = "com.apple.focus.work";                display = "仕事"; }
  ];
  focusShortcuts = pkgs.callPackage ../../pkgs/focus-shortcuts { modes = focusModes; };

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

  # メニューの行にマウスが乗ったら背景を付ける
  hover = plugin "hover" ''
    case "$SENDER" in
      mouse.entered) sketchybar --set "$NAME" background.drawing=on ;;
      mouse.exited)  sketchybar --set "$NAME" background.drawing=off ;;
    esac
  '';


  # 各プラグインの先頭: 操作スクリプトの場所を渡して共通関数を読み込む
  header = ''
    ACTION=${action}
    . ${shLib}
  '';

  # 予定の追加など（pkgs/calendar/event.js。EventKit を JXA で呼ぶ。カレンダーアプリは開かない）
  calEvent = "osascript -l JavaScript ${../../pkgs/calendar/event.js}";
  # 時間を選ぶ画面（開始・終了のプルダウン + 終日。pkgs/calendar/timepicker.js）
  calTimePicker = "osascript -l JavaScript ${../../pkgs/calendar/timepicker.js}";

  # カレンダーを画像で描く（pkgs/calendar/render.py。祝日と予定の件数は Homebrew の icalBuddy で読む）
  calRender = "${pkgs.python3.withPackages (ps: [ ps.pillow ])}/bin/python3 ${../../pkgs/calendar/render.py}";
}
