# ytplay [オプション…] <URL または ファイル…>: YouTube を yt-dlp で取りながら mpv で再生する。
#   mpv に YouTube の URL を直接渡すと多くの動画で 403 Forbidden になる（2026-10）ので、yt-dlp の出力を流し込む。
#   標準入力ではなくプロセス置換で渡すので、ターミナルから起動したときは mpv をキーで操作できる。
#
#   --no-video  音声だけ取る          --term     ターミナルの中に文字で描く（mpv の tct、360p）
#   --pane      cmux なら今のペインの下に新しいペインを開き、その中で --term 再生する（終わると閉じる）。
#               youtube-tui の画面の上で直接再生すると、戻ったときに youtube-tui の表示が崩れるため。cmux の外では --term と同じ
#   --loop      最後まで行ったら繰り返す  --shuffle  順番を混ぜる
#   ほかの「-」で始まる引数は mpv にそのまま渡す。
#   再生リスト・チャンネルの URL は中の動画を順に再生する。q で全部止める（mpv の 1 本だけなら閉じても次へ進む）。
#   URL でないもの（保存済みのファイル）は mpv で直接再生する。
fmt="bv*[height<=1080]+ba/b" args=() urls=() files=() loop="" shuffle="" term=""
# --pane: cmux の中なら、新しいペインで自分（--pane を除いた引数で --term）を動かして、すぐ戻る
if printf '%s\n' "$@" | grep -qx -- --pane; then
  rest=()
  for a in "$@"; do [ "$a" = --pane ] || rest+=("$a"); done
  if [ -n "${CMUX_SURFACE_ID:-}" ] && command -v cmux >/dev/null 2>&1; then
    cmd=$(printf '%q ' "$0" --term "${rest[@]}")
    exec cmux new-split down --command "$cmd; exit" --focus true >/dev/null 2>&1
  fi
  set -- --term "${rest[@]}"
fi
for a in "$@"; do
  case "$a" in
    --no-video) fmt="ba/b"; args+=("$a") ;;
    --term) term=1 ;;
    --loop) loop=1 ;;
    --shuffle) shuffle=1 ;;
    -*) args+=("$a") ;;
    http*) urls+=("$a") ;;
    *) files+=("$a") ;;
  esac
done
if [ -n "$term" ]; then
  # youtube-tui の run は画面出力を捨てるので、ターミナルに直接つなぎ直す（キー操作も同じターミナルから）
  exec </dev/tty >/dev/tty 2>/dev/null
  if [ "$fmt" != "ba/b" ]; then
    fmt="bv*[height<=360]+ba/b"
    args=(--vo=tct --really-quiet "${args[@]}")
  fi
fi
# q を押したら終了コード 9 にして、残りの再生をやめる（最後まで再生したときは 0）
args=(--input-conf="$YTPLAY_INPUT_CONF" "${args[@]}")

# 保存済みのファイル: mpv で直接（ループ・シャッフルは mpv の機能で）
if [ ${#files[@]} -gt 0 ]; then
  extra=()
  [ -n "$loop" ] && extra+=(--loop-playlist=inf)
  [ -n "$shuffle" ] && extra+=(--shuffle)
  exec mpv "${extra[@]}" "${args[@]}" "${files[@]}"
fi
[ ${#urls[@]} -gt 0 ] || { echo "使い方: ytplay [--no-video] [--term] [--loop] [--shuffle] [mpv のオプション…] <URL…>" >&2; exit 2; }

# 再生リスト・チャンネルは中の動画の URL に展開する
list=()
for u in "${urls[@]}"; do
  case "$u" in
    *list=* | */playlist* | */channel/* | */@* | */c/* | */user/*)
      while IFS= read -r v; do [ -n "$v" ] && list+=("$v"); done \
        < <(yt-dlp -q --no-warnings --flat-playlist --print url "$u") ;;
    *) list+=("$u") ;;
  esac
done
[ ${#list[@]} -gt 0 ] || { echo "ytplay: 再生できる動画がありません" >&2; exit 1; }

while :; do
  order=("${list[@]}")
  if [ -n "$shuffle" ]; then
    order=()
    while IFS= read -r v; do order+=("$v"); done < <(printf '%s\n' "${list[@]}" | sort -R)
  fi
  for u in "${order[@]}"; do
    # AV1 はハードウェアで再生できない Mac があるので、h264 → vp9 を優先する
    mpv "${args[@]}" <(yt-dlp -q --no-warnings -S "vcodec:h264,vcodec:vp9" -f "$fmt" -o - "$u")
    [ $? -eq 9 ] && exit 0
  done
  [ -n "$loop" ] || break
done
