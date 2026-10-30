# sketchybar の代わりにアクセシビリティが必要な操作（固定の一覧）だけを行う常駐プログラム（main.m）。
# アクセシビリティの許可はこれだけに与える
{ stdenv }:
stdenv.mkDerivation {
  pname = "ax-agent";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    $CC -O2 -Wall -fobjc-arc -o ax-agent main.m -framework AppKit -framework ApplicationServices
  '';
  installPhase = ''
    install -Dm755 ax-agent $out/bin/ax-agent
  '';
}
