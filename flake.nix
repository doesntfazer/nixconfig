{
  description = "NixOS with Secure Boot via Lanzaboote";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2"; # <-- was v0.4.3
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        lanzaboote.nixosModules.lanzaboote
        ({ lib, pkgs, ... }: {
          environment.systemPackages = [ pkgs.sbctl ];
          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.lanzaboote = {
            enable = true;
            # You can keep this, or switch to a repo-local dir like: ./secureboot
            pkiBundle = "/var/lib/sbctl";
          };
        })
      ];
    };
  };
}
