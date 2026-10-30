# ymuse（mpd の GUI）を Mac で正しく表示するための手直し。
# - nixpkgs の Mac 版は、画像を読む部品の一覧（loaders.cache）に SVG が入っておらず、
#   ボタンのアイコンが灰色の四角になる → SVG を含む一覧を作り直して使う
# - 起動用の包み（wrapper）の名前が「.ymuse-wrapped」でバーのアプリ名に出る → 包み方を変える
{
  runCommand,
  makeWrapper,
  cctools,
  darwin,
  ymuse,
  gdk-pixbuf,
  librsvg,
  adwaita-icon-theme,
  hicolor-icon-theme,
  shared-mime-info,
}:
let
  # librsvg の SVG 部品は、自分が使う librsvg-2.2.dylib の場所（@rpath）が解決できず読み込めない。
  # コピーして場所を直接書き込み、署名し直す（Apple Silicon は署名がないと読み込めない）
  loaders = runCommand "gdk-pixbuf-loaders-with-svg" { nativeBuildInputs = [ cctools ]; } ''
    mkdir -p $out
    svg=$out/libpixbufloader_svg.dylib
    cp ${librsvg.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.dylib $svg
    chmod u+w $svg
    install_name_tool \
      -change @rpath/librsvg-2.2.dylib ${librsvg.out}/lib/librsvg-2.2.dylib $svg
    ${darwin.sigtool}/bin/codesign -f -s - $svg
    ${gdk-pixbuf.dev}/bin/gdk-pixbuf-query-loaders \
      ${gdk-pixbuf.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so $svg > $out/loaders.cache
    grep -q svg $out/loaders.cache # SVG が入っていなければビルドを止める
  '';
in
ymuse.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ makeWrapper ];
  dontWrapGApps = true;
  postFixup = (old.postFixup or "") + ''
    mkdir -p $out/libexec
    mv $out/bin/ymuse $out/libexec/ymuse
    makeWrapper $out/libexec/ymuse $out/bin/ymuse "''${gappsWrapperArgs[@]}" \
      --set GDK_PIXBUF_MODULE_FILE ${loaders}/loaders.cache \
      --prefix XDG_DATA_DIRS : ${adwaita-icon-theme}/share:${hicolor-icon-theme}/share:${shared-mime-info}/share
  '';
})
