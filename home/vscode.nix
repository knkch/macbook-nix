{ pkgs, ... }:
{
  # userSettings は home-manager 管理外（VSCode が settings.json に直接書き込めるようにするため）
  # 拡張は profiles.default.extensions で管理（home-manager 25.05 での正式オプション名）
  programs.vscode = {
    enable = true;
    profiles.default.extensions =
      (with pkgs.vscode-extensions; [
        # Remote
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-containers
        # Language pack
        ms-ceintl.vscode-language-pack-ja
        # Python
        ms-python.python
        ms-python.debugpy
        # Go
        golang.go
        # Git
        eamodio.gitlens
        mhutchie.git-graph
      ])
      ++ [
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            publisher = "srl-labs";
            name      = "vscode-containerlab";
            version   = "0.26.3";
            hash      = "sha256-YMuigJ6lHZI+Q1wqmsbnB00IgvvZLX0Wr5jBvoEg9+A=";
          };
        })
      ];
  };
}
