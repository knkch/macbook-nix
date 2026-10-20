{ pkgs, lib, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
    ./git.nix
    ./nixvim.nix
    ./desktop.nix
    ./vscode.nix
  ];

  # ── User / Home ─────────────────────────────────────────────────────────── #
  home.username      = "konkichi";
  home.homeDirectory = lib.mkForce "/Users/konkichi";
  home.stateVersion  = "25.05";

  programs.home-manager.enable = true;

  # ── Dotfiles ────────────────────────────────────────────────────────────── #

  # macSKK 辞書設定（GUI で設定する場合はこのブロックをコメントアウト）
  home.file."Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings.json" = {
    text = builtins.toJSON {
      dictionaries = [{
        filename = "${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L";
        enabled  = true;
        type     = 0;        # 0 = ファイル辞書
        encoding = "euc-jp";
      }];
    };
  };

  # Blu-ray AACS キーデータベース格納先
  # keydb.cfg は FindVUK Online Database から手動でダウンロードして配置する
  home.file."Library/Preferences/aacs/.keep".text = "";

  # VSCode 表示言語を日本語に固定
  home.file."Library/Application Support/Code/User/locale.json".text = ''
    { "locale": "ja" }
  '';
}
