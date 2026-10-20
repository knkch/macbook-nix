{ lib, ... }:
{
  # ── Zsh ─────────────────────────────────────────────────────────────────── #
  # compinit は home-manager（enableCompletion）が実行するので手動で呼ばない
  # kubectl / helm 等の補完は nix パッケージ同梱のものが fpath 経由で読まれる
  programs.zsh = {
    enable                    = true;
    autosuggestion.enable     = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin";
      ll      = "eza -la --icons";
      cat     = "bat";
      lg      = "lazygit";
      # Blu-ray 再生: BD-J メニューに OpenJDK 17 が必要（最新 JDK はクラッシュ）
      # `open` 経由では環境変数が渡らないため --env で指定する
      vlc-bd  = "open --env JAVA_HOME=/opt/homebrew/opt/openjdk@17 -a VLC";
    };
    initContent = lib.mkMerge [
      ''
        zstyle ':completion:*' menu select
        WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
      ''
      # fzf も <C-r> を奪うので、最後に atuin へ割り当て直す
      (lib.mkAfter ''
        bindkey '^r' atuin-search
      '')
    ];
  };

  # ── Starship ─────────────────────────────────────────────────────────────── #
  # programs.starship.presets は home-manager 25.05 に未対応のため settings で代替
  programs.starship = {
    enable = true;
    settings = {
      # nerd-font-symbols プリセット相当（nixpkgs-25.05 の starship が対応するキーのみ）
      aws.symbol            = "  ";
      buf.symbol            = " ";
      c.symbol              = " ";
      conda.symbol          = " ";
      dart.symbol           = " ";
      directory.read_only   = " 󰌾";
      docker_context.symbol = " ";
      elixir.symbol         = " ";
      elm.symbol            = " ";
      git_branch.symbol     = " ";
      golang.symbol         = " ";
      haskell.symbol        = " ";
      hostname.ssh_symbol   = " ";
      java.symbol           = " ";
      julia.symbol          = " ";
      kotlin.symbol         = " ";
      lua.symbol            = " ";
      memory_usage.symbol   = "󰍛 ";
      nim.symbol            = "󰆥 ";
      nix_shell.symbol      = " ";
      nodejs.symbol         = " ";
      ocaml.symbol          = " ";
      package.symbol        = "󰏗 ";
      perl.symbol           = " ";
      php.symbol            = " ";
      python.symbol         = " ";
      ruby.symbol           = " ";
      rust.symbol           = " ";
      scala.symbol          = " ";
      swift.symbol          = " ";
      zig.symbol            = " ";
    };
  };

  # ── 履歴 / 移動 / 検索 ──────────────────────────────────────────────────── #
  # atuin: <C-r> 履歴 fuzzy 検索・同期
  programs.atuin.enable = true;

  # zoxide: `z <dir>` で履歴学習型移動
  programs.zoxide.enable = true;

  # fzf: <C-t> ファイル検索 / Alt-c ディレクトリ移動（<C-r> は atuin）
  programs.fzf.enable = true;

  # ── CLI ツール ───────────────────────────────────────────────────────────── #
  programs.bat.enable     = true;
  programs.eza.enable     = true;
  programs.lazygit.enable = true;   # `lg` で起動

  # direnv + nix-direnv: `.envrc` に `use flake` と書いて `direnv allow`
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };
}
