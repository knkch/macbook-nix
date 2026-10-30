{ ... }:
{
  # ファイルマネージャー。`yy` で開くと、終了したときにそのフォルダへ移動する
  # 既定で 写真 → open（プレビュー）、動画・音声 → mpv（別ウィンドウ）で開く。
  # ここでは音声をターミナル内で再生し、動画もターミナル内で再生できるようにする
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      opener = {
        # 音声: 別ウィンドウを出さずにその場で再生（space で一時停止、q で戻る）
        play-term = [
          {
            run = ''mpv --no-video "$@"'';
            block = true;
            desc = "ターミナルで再生";
            for = "unix";
          }
        ];
        # 動画: ターミナルの中に映す（Kitty 方式）
        play-kitty = [
          {
            run = ''mpv --vo=kitty --really-quiet "$@"'';
            block = true;
            desc = "ターミナル内で再生";
            for = "unix";
          }
        ];
      };

      # Enter は先頭の開き方、O で一覧から選べる
      open.prepend_rules = [
        { mime = "audio/*"; use = [ "play-term" "play" "reveal" ]; }
        { mime = "video/*"; use = [ "play" "play-kitty" "reveal" ]; }
      ];
    };
  };
}
