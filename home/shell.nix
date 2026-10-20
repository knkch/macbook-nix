{ ... }:
{
  # ── Zsh ─────────────────────────────────────────────────────────────────── #
  programs.zsh = {
    enable                    = true;
    autosuggestion.enable     = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      rebuild = "darwin-rebuild switch --flake ~/.config/nix-darwin";
      ll      = "eza -la --icons";
      cat     = "bat";
      lg      = "lazygit";
      # Blu-ray 再生: BD-J メニューに OpenJDK 17 が必要（最新 JDK はクラッシュ）
      vlc-bd  = "JAVA_HOME=/opt/homebrew/opt/openjdk@17 open -a VLC";
    };
    initContent = ''
      autoload -Uz compinit && compinit
      zstyle ':completion:*' menu select
      WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
      eval "$(atuin init zsh)"
      source <(kubectl completion zsh)
      source <(helm completion zsh)
    '';
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

  # ── Zoxide ───────────────────────────────────────────────────────────────── #
  # 使い方: `z <dir>` で履歴学習型移動
  programs.zoxide = {
    enable               = true;
    enableZshIntegration = true;
  };

  # ── Fzf ──────────────────────────────────────────────────────────────────── #
  # <C-r> 履歴検索 / <C-t> ファイル検索 / Alt-c ディレクトリ移動
  programs.fzf = {
    enable               = true;
    enableZshIntegration = true;
  };

  # ── Lazygit ──────────────────────────────────────────────────────────────── #
  # 使い方: `lg` で起動
  programs.lazygit.enable = true;

  # ── Direnv + nix-direnv ──────────────────────────────────────────────────── #
  # 使い方: プロジェクトルートに `.envrc` を作り `use flake` と書いて `direnv allow`
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };
}
