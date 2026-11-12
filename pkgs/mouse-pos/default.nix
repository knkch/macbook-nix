# マウスの位置を出す小さなコマンド（main.c）。sketchybar のメニューを閉じる判定に使う
{ stdenv }:
stdenv.mkDerivation {
  pname = "mouse-pos";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    $CC -O2 -Wall -o mouse-pos main.c -framework ApplicationServices
  '';
  installPhase = ''
    install -Dm755 mouse-pos $out/bin/mouse-pos
  '';
}
