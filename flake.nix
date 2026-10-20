{
  description = "KokinoMacBook-Pro nix-darwin configuration";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nix-darwin.url   = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nixvim.url       = "github:nix-community/nixvim/nixos-25.05";

    nix-darwin.inputs.nixpkgs.follows   = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.nixpkgs.follows       = "nixpkgs";
  };

  outputs = inputs @ { self, nix-darwin, home-manager, nixvim, ... }:
  {
    darwinConfigurations."KokinoMacBook-Pro" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self; };
      modules = [
        ./modules/system.nix
        ./modules/homebrew.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs       = true;
          home-manager.useUserPackages     = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.konkichi      = import ./home;
          home-manager.sharedModules       = [ nixvim.homeModules.nixvim ];
        }
      ];
    };
  };
}
