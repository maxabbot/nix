{
  description = "NixOS system configuration — home-desktop / work-laptop / minimal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland/v0.55.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      zen-browser,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      mkPkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ (import ./overlays) ];
      };

      # Builds a NixosSystem with Home Manager wired in.
      # hmArgs are passed as extraSpecialArgs to the HM user config.
      mkHost =
        {
          hostName,
          machineType,
          modules,
          hmArgs ? { },
        }:
        lib.nixosSystem {
          inherit system;
          pkgs = mkPkgs;
          specialArgs = {
            inherit
              inputs
              nixos-hardware
              zen-browser
              hostName
              machineType
              ;
          };
          modules = modules ++ [
            inputs.hyprland.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.sharedModules = [ inputs.hyprland.homeManagerModules.default ];
              home-manager.extraSpecialArgs = hmArgs // {
                inherit inputs;
              };
              home-manager.users.max = import ./home/max;
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        # RTX 40-series desktop — full stack
        home-desktop = mkHost {
          hostName = "home-desktop";
          machineType = "desktop";
          modules = [
            ./hosts/home-desktop
            disko.nixosModules.disko
          ];
          hmArgs = {
            machineType = "desktop";
            compositor = "hyprland";
            monitors = {
              # DP-2: 4K portrait monitor (left); logical size after 90° rotation = 2160x3840
              secondary = "DP-2,3840x2160@60,0x0,1,transform,1";
              # DP-3: primary 1440p gaming monitor (right)
              primary = "DP-3,2560x1440@165,2160x0,1";
              primaryName = "DP-3";
            };
            location = {
              latitude = -43.53;
              longitude = 172.64;
            };
            git = {
              name = "Max Abbot";
              email = "abbot.max.nz@gmail.com";
              signingkey = "";
            };
          };
        };

        # Development laptop — no GPU/gaming
        work-laptop = mkHost {
          hostName = "work-laptop";
          machineType = "laptop";
          modules = [
            ./hosts/work-laptop
            disko.nixosModules.disko
          ];
          hmArgs = {
            machineType = "laptop";
            compositor = "hyprland";
            monitors = {
              primary = null;
              secondary = null;
            };
            location = {
              latitude = 51.5;
              longitude = -0.1;
            };
            git = {
              name = "Max Abbot";
              email = "abbot.max.nz@gmail.com";
              signingkey = "";
            };
          };
        };

        # Minimal — base packages only
        minimal = mkHost {
          hostName = "minimal";
          machineType = "desktop";
          modules = [ ./hosts/minimal ];
          hmArgs = {
            machineType = "desktop";
            compositor = "hyprland";
            monitors = {
              primary = "";
              secondary = "";
            };
            location = {
              latitude = -43.53;
              longitude = 172.64;
            };
            git = {
              name = "Max Abbot";
              email = "abbot.max.nz@gmail.com";
              signingkey = "";
            };
          };
        };
      };
    };
}
