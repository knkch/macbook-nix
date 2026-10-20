{ ... }:
{
  programs.nixvim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;

    colorschemes.tokyonight.enable = true;

    opts = {
      number         = true;
      relativenumber = true;
      tabstop        = 2;
      shiftwidth     = 2;
      expandtab      = true;
    };

    # ── LSP ──────────────────────────────────────────────────────────────── #
    plugins.lsp = {
      enable = true;
      keymaps = {
        diagnostic = {
          "<leader>j" = "goto_next";
          "<leader>k" = "goto_prev";
        };
        lspBuf = {
          "gd"         = "definition";
          "gD"         = "declaration";
          "K"          = "hover";
          "gi"         = "implementation";
          "gr"         = "references";
          "<leader>rn" = "rename";
          "<leader>ca" = "code_action";
        };
      };
      servers = {
        gopls.enable   = true;
        pyright.enable = true;
        nil_ls.enable  = true;
        yamlls.enable  = true;
        clangd.enable  = true;
        ts_ls.enable   = true;
        rust_analyzer = {
          enable       = true;
          installCargo = true;
          installRustc = true;
        };
      };
    };

    # ── Completion ───────────────────────────────────────────────────────── #
    plugins.cmp = {
      enable = true;
      settings = {
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "buffer"; }
          { name = "path"; }
        ];
        mapping = {
          "<C-Space>" = "cmp.mapping.complete()";
          "<CR>"      = "cmp.mapping.confirm({ select = true })";
          "<Tab>"     = "cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' })";
          "<S-Tab>"   = "cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 's' })";
          "<C-e>"     = "cmp.mapping.abort()";
        };
        snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
      };
    };
    plugins.luasnip.enable      = true;
    plugins.cmp-nvim-lsp.enable = true;
    plugins.cmp-buffer.enable   = true;
    plugins.cmp-path.enable     = true;

    # ── Fuzzy Finder ─────────────────────────────────────────────────────── #
    plugins.telescope = {
      enable = true;
      keymaps = {
        "<leader>ff" = "find_files";
        "<leader>fg" = "live_grep";
        "<leader>fb" = "buffers";
        "<leader>fh" = "help_tags";
      };
    };

    # ── Syntax ───────────────────────────────────────────────────────────── #
    plugins.treesitter.enable                    = true;
    plugins.treesitter.settings.highlight.enable = true;

    # ── UI ───────────────────────────────────────────────────────────────── #
    plugins.lualine = {
      enable = true;
      settings.options = {
        theme                = "auto";
        component_separators = { left = ""; right = ""; };
        section_separators   = { left = ""; right = ""; };
      };
    };
    plugins.gitsigns = {
      enable = true;
      settings.signs = {
        add.text          = "│";
        change.text       = "│";
        delete.text       = "_";
        topdelete.text    = "‾";
        changedelete.text = "~";
      };
    };
    plugins.nvim-tree.enable = true;
    plugins.toggleterm = {
      enable = true;
      settings = {
        open_mapping      = "[[<C-t>]]";
        direction         = "float";
        float_opts.border = "curved";
      };
    };
    plugins.indent-blankline.enable = true;
    plugins.nvim-autopairs.enable   = true;
    plugins.comment.enable          = true;
    plugins.web-devicons.enable     = true;
    plugins.which-key.enable        = true;
    plugins.trouble.enable          = true;
  };
}
