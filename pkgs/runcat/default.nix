# sketchybar で CPU 使用率に合わせて走る猫（RunCat 風・オリジナルの絵）を gen.py で描く
{ runCommand, python3 }:
runCommand "sketchybar-runcat-frames" {
  nativeBuildInputs = [ (python3.withPackages (ps: [ ps.pillow ])) ];
} ''
  python3 ${./gen.py} $out
''
