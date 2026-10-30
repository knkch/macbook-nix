{
  description = "KokinoMacBook-Pro nix-darwin configuration";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nix-darwin.url   = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nixvim.url       = "github:nix-community/nixvim/nixos-25.05";
    # 25.05 にない新しい版が要るものだけ使う（今は youtube-tui・yt-dlp。home/packages.nix の pkgsUnstable）
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.inputs.nixpkgs.follows   = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.nixpkgs.follows       = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-darwin, home-manager, nixvim, ... }:
  let
    system = "aarch64-darwin";
    host   = "KokinoMacBook-Pro";
    # ユーザー名はここだけで定義し、各モジュールへ引数 `user` として渡す
    user   = "konkichi";
  in
  {
    darwinConfigurations.${host} = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self user; };
      modules = [
        ./modules/system.nix
        ./modules/homebrew.nix
        ./modules/desktop.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs       = true;
          home-manager.useUserPackages     = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs    = {
            inherit user;
            pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};
          };
          home-manager.users.${user}       = import ./home;
          home-manager.sharedModules       = [ nixvim.homeModules.nixvim ];
        }
      ];
    };

    # `nix fmt` で整形
    formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
  };
}
