# focus-shortcuts: 集中モードの切り替え用ショートカット「集中モード: <名前> オン / オフ」を用意するコマンド。
# 足りないものだけを署名して取り込み画面を開く（そろっていれば何もしない）。`--check` は確認だけ。
#   終了コード: 0 = そろっている / 1 = 足りない（--check のとき）/ 2 = ショートカットの一覧を読めない
# ショートカットの中身（署名前）はビルド時に gen.py で作る。署名と取り込みは macOS にログイン中の
# ユーザーでしかできないので実行時に行う。取り込みの「追加」ボタンは macOS の仕様で手で押す。
{ runCommand, writeShellScriptBin, python3, modes }:
let
  unsigned = runCommand "focus-shortcuts-unsigned" {
    nativeBuildInputs = [ python3 ];
    modesJson = builtins.toJSON modes;
    passAsFile = [ "modesJson" ];
  } ''
    python3 ${./gen.py} "$modesJsonPath" "$out"
  '';
in
writeShellScriptBin "focus-shortcuts" ''
  set -u
  case "''${1:-}" in
    -h | --help)
      echo "使い方: focus-shortcuts [--check]"
      echo "  集中モードの切り替え用ショートカットのうち、足りないものを取り込む（--check は確認だけ）"
      exit 0 ;;
  esac

  # ショートカットの名前は濁点が分かれた形（NFD）で返るので、まとめた形（NFC）にそろえて比べる
  list="$(/usr/bin/shortcuts list 2>/dev/null)" || { echo "ショートカットの一覧を読めません" >&2; exit 2; }
  list="$(printf '%s\n' "$list" | /usr/bin/iconv -f UTF-8-MAC -t UTF-8)"

  missing=()
  while IFS=$'\t' read -r file name; do
    if printf '%s\n' "$list" | /usr/bin/grep -qxF -- "$name"; then
      echo "✓ $name"
    else
      echo "✗ ''${name}（ありません）"
      missing+=("$file"$'\t'"$name")
    fi
  done < ${unsigned}/manifest.tsv

  if [ ''${#missing[@]} -eq 0 ]; then echo "すべてそろっています"; exit 0; fi
  [ "''${1:-}" = --check ] && exit 1

  out="''${TMPDIR:-/tmp}/focus-shortcuts"
  mkdir -p "$out"
  for m in "''${missing[@]}"; do
    file="''${m%%$'\t'*}"; name="''${m#*$'\t'}"
    rm -f "$out/$name.shortcut"
    if /usr/bin/shortcuts sign --mode anyone --input "${unsigned}/$file" --output "$out/$name.shortcut" >/dev/null 2>&1; then
      /usr/bin/open "$out/$name.shortcut"
      sleep 1
    else
      echo "署名できませんでした: $name" >&2
    fi
  done
  echo "取り込み画面で「ショートカットを追加」を押してください（そのあとフォルダ「SketchyBar」へ移すと整理できます）"
''
