{ config, lib, pkgs, ... }:
{
  # ── 音楽: mpd（再生の本体・常駐）+ rmpc（TUI。アルバムアート対応）+ mpc（コマンドで操作）── #
  # 曲は ~/Music/MyLibrary（アーティスト別のフォルダ。ほぼ FLAC）
  services.mpd = {
    enable = true;                       # macOS では launchd でログイン時に起動
    musicDirectory = "${config.home.homeDirectory}/Music/MyLibrary";
    network.listenAddress = "127.0.0.1"; # このマシンからだけ操作できる（ポート 6600）
    extraConfig = ''
      audio_output {
        type        "osx"
        name        "CoreAudio"
        mixer_type  "software"
      }
    '';
  };

  # mpd のデータとログの置き場所（macOS では home-manager が作らないので、ないと mpd が起動に失敗する）
  home.activation.mpdDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.home.homeDirectory}/.local/share/mpd/playlists" "${config.home.homeDirectory}/Library/Logs/mpd"
  '';

  # rmpc: アルバムアートは Ghostty / cmux の画像表示（kitty プロトコル）で出る。
  # 設定は home/rmpc/config.ron、テーマ（tokyonight）は home/rmpc/tokyonight.ron
  programs.rmpc = {
    enable = true;
    config = builtins.readFile ./rmpc/config.ron;
  };
  xdg.configFile."rmpc/themes/tokyonight.ron".source = ./rmpc/tokyonight.ron;

  home.packages = [ pkgs.mpc ]; # mpc toggle / next / prev / update など

  home.shellAliases.music = "rmpc"; # 「music」で操作画面を開く
}
