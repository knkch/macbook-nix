{ ... }:
{
  # VS Code 本体と拡張は Homebrew で管理（modules/homebrew.nix）
  #   - 本体: cask "visual-studio-code"（nixpkgs 版より更新が早い）
  #   - 拡張: Brewfile の `vscode` 行（Marketplace 最新版・pylance も使える）
  # settings.json は VS Code が直接書き込めるよう Nix 管理外

  # 表示言語を日本語に固定
  home.file."Library/Application Support/Code/User/locale.json".text = ''
    { "locale": "ja" }
  '';
}
