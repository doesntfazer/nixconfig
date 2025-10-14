{
  description = "NixOS with Secure Boot via Lanzaboote + winboat + Docker + FreeRDP";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2"; # was v0.4.3
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add winboat
    winboat = {
      url = "github:TibixDev/winboat";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, winboat, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      # make winboat available to modules
      specialArgs = { inherit winboat; };

      modules = [
        ./configuration.nix
        lanzaboote.nixosModules.lanzaboote

        ({ lib, pkgs, ... }: {
          ############################
          # Secure Boot (as before)  #
          ############################
          environment.systemPackages = [
            pkgs.sbctl
            # winboat binary for this host
            (winboat.packages.${pkgs.stdenv.hostPlatform.system}.winboat)
            # Docker Compose v2 shim and CLI
            pkgs.docker-compose
            # FreeRDP 3.x (xfreerdp)
            pkgs.freerdp
          ];

          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
          };

          #####################################
          # Docker daemon + group membership  #
          #####################################
          virtualisation.docker.enable = true;  # starts docker and enables at boot

          # Add your user to the docker group (adjust if your username differs)
          users.users.alex.extraGroups = lib.mkAfter [ "docker" ];

          # If winboat/docker requires legacy iptables modules, uncomment:
          # boot.kernelModules = [ "ip_tables" "iptable_nat" ];
          # Otherwise, nftables default is fine.
        })
      ];
    };
  };
}
