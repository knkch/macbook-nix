# 画面の上端・上の角のクリックを sketchybar に届くよう少し内側に移す常駐プログラム（main.c）
{ stdenv }:
stdenv.mkDerivation {
  pname = "menubar-click-guard";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    $CC -O2 -Wall -o menubar-click-guard main.c -framework ApplicationServices
  '';
  installPhase = ''
    install -Dm755 menubar-click-guard $out/bin/menubar-click-guard
  '';
}
