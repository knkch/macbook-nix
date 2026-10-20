{ pkgs, user, ... }:
{
  imports = [
    ./packages.nix
    ./security.nix
    ./shell.nix
    ./git.nix
    ./nixvim.nix
    ./desktop.nix
    ./vscode.nix
  ];

  # ── User / Home ─────────────────────────────────────────────────────────── #
  # homeDirectory は nix-darwin の users.users.<user>.home から自動で決まる
  home.username     = user;
  home.stateVersion = "25.05";

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
}
