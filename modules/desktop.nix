# デスクトップの常駐サービス: sketchybar（./sketchybar）・jankyborders・menubar-click-guard
{ pkgs, ... }:
{
  imports = [ ./sketchybar ];

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
}
