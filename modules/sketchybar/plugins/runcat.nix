ctx:
let
  inherit (ctx) pkgs plugin;
in
rec {
  # ── CPU に合わせて走る猫（RunCat 風・絵はオリジナル）。ノッチのすぐ右 ────── #
  # 使用率を約 1 秒ごとに測り、コマの間隔を 0.2 秒（暇）〜 0.03 秒（全開）で変える。右に使用率を表示
  runcatFrames = pkgs.callPackage ../../../pkgs/runcat { };
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
}
