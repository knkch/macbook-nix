# 通知の履歴と集中モードの状態（どちらも macOS の保護領域）を読み、sketchybar 用にキャッシュへ書き出す常駐プログラム（main.m）。
# フルディスクアクセスはこれだけに与える
{ stdenv, sqlite }:
stdenv.mkDerivation {
  pname = "protected-reader";
  version = "1.0";
  src = ./.;
  buildInputs = [ sqlite ];
  buildPhase = ''
    $CC -O2 -Wall -fobjc-arc -o protected-reader main.m -framework Foundation -lsqlite3
  '';
  installPhase = ''
    install -Dm755 protected-reader $out/bin/protected-reader
  '';
}
