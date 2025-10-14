{
  description = "NixOS with winboat + Docker + FreeRDP";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    winboat = {
      url = "github:TibixDev/winboat";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, winboat, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = { inherit winboat; };

      modules = [
        ./configuration.nix

        ({ lib, pkgs, ... }: {

          environment.systemPackages = [
            (winboat.packages.${pkgs.stdenv.hostPlatform.system}.winboat)
            pkgs.docker-compose
            pkgs.freerdp
          ];

          virtualisation.docker.enable = true;
          users.users.alex.extraGroups = lib.mkAfter [ "docker" ];
        })
      ];
    };
  };
}
