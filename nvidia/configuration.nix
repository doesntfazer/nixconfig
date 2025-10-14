{ config, pkgs, ... }:

let
  ext = pkgs.gnomeExtensions;

  # Samba share credentials file path (create it manually with mode 600):
  # /etc/nixos/secrets/smb-192.168.0.33-share
  credPath = "/etc/nixos/secrets/smb-192.168.0.33-share";

  # Resolve alex's uid/gid for CIFS ownership mapping
  uidNum = (config.users.users.alex.uid or 1000);
  gidNum = (config.users.groups.users.gid or 100);
in
{
  imports = [
    /etc/nixos/hardware-configuration.nix
   # ./lanzaboote.nix
  ];

  # Enable Nix Experimental
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # -----------------------------
  # Filesystems (inlined modules)
  # -----------------------------

#  Mounted games drive
#  fileSystems."/home/alex/games" = {
#    device = "/dev/disk/by-uuid/517f09af-0fbf-4a47-b40b-b26fe6e1ef02";
#    fsType  = "ext4";
#    # options = [ "noatime" "nodiratime" ];
#  };

  # Ensure mountpoint for CIFS share exists (owned by alex:users)
  systemd.tmpfiles.rules = [
    "d /home/alex/share 0755 alex users - -"
  ];

  # -----------------------------
  # Display server + GNOME
  # -----------------------------
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable Tailscale
  services.tailscale.enable = true;

  # Autologin (disabled but keep user set)
  services.displayManager.autoLogin.enable = false;
  services.displayManager.autoLogin.user = "alex";

  # GNOME shell defaults + enable only dash-to-panel
  services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.wm.preferences]
    button-layout=':minimize,maximize,close'

    [org.gnome.desktop.peripherals.mouse]
    accel-profile='flat'
    speed=0.0

    [org.gnome.desktop.peripherals.touchpad]
    accel-profile='flat'
    speed=0.0

    [org.gnome.desktop.interface]
    clock-format='12h'

    [org.gnome.shell]
    disable-user-extensions=false
    enabled-extensions=['dash-to-panel@jderose9.github.com']
  '';

  # Input
  services.libinput = {
    enable = true;
    mouse = { accelProfile = "flat"; accelSpeed = "0"; };
    touchpad = { accelProfile = "flat"; accelSpeed = "0"; };
  };

  # --- Copy monitors.xml for GDM before it starts ---
  systemd.services.copyGdmMonitorsXml = {
    description = "Copy monitors.xml to GDM runtime config before GDM starts";
    before = [ "display-manager.service" ];
    wantedBy = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = (pkgs.writeShellScript "copy-gdm-monitors-xml" ''
        set -eu
        SRC="/home/alex/.config/monitors.xml"
        DEST_DIR="/run/gdm/.config"
        DEST="$DEST_DIR/monitors.xml"
        if [ -r "$SRC" ]; then
          mkdir -p "$DEST_DIR"
          install -m 0644 "$SRC" "$DEST"
          chown gdm:gdm "$DEST"
          echo "Copied $SRC -> $DEST"
        else
          echo "No $SRC; skipping."
        fi
      '');
    };
  };
  # --------------------------------------------------

  # -----------------------------
  # Graphics / NVIDIA
  # -----------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    powerManagement.enable = true;
    nvidiaSettings = true;
  };

  # -----------------------------
  # Steam + Vulkan runtime env
  # -----------------------------
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraPackages = with pkgs; [ vulkan-tools libva libva-utils ];
  };

  environment.variables = {
    VK_ICD_FILENAMES =
      "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:/run/opengl-driver-32/share/vulkan/icd.d/nvidia_icd.json";
    VK_LAYER_PATH =
      "/run/opengl-driver/share/vulkan/explicit_layer.d:/run/opengl-driver-32/share/vulkan/explicit_layer.d";
  };

  # Keyboard layout
  services.xserver.xkb = { layout = "us"; variant = ""; };

  # -----------------------------
  # Audio
  # -----------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # -----------------------------
  # Printing (Epson XP-970)
  # -----------------------------
  services.printing.enable = true;

  systemd.services."epson-xp970-setup" = {
    description = "Create CUPS queue for Epson XP-970 (driverless IPP)";
    after = [ "cups.service" "network-online.target" ];
    requires = [ "cups.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "setup-epson-xp970" ''
        set -eu
        PRN="Epson_XP-970"
        URI="ipp://10.0.0.111/ipp/print"
        if ${pkgs.cups}/bin/lpstat -v "$PRN" >/dev/null 2>&1; then exit 0; fi
        ${pkgs.cups}/bin/lpadmin -x "$PRN" || true
        ${pkgs.cups}/bin/lpadmin -p "$PRN" -E -v "$URI" -m everywhere
        ${pkgs.cups}/bin/lpoptions -d "$PRN"
      '';
    };
  };

  # -----------------------------
  # Users
  # -----------------------------
  users.users.alex = {
    isNormalUser = true;
    description = "alex";
    extraGroups = [ "networkmanager" "wheel" ];
    # uid = 1000;  # (optional) pin this if you want to guarantee uid
  };

  # -----------------------------
  # Packages & unfree
  # -----------------------------
  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vscode
    steam
    google-chrome
    orca-slicer
    davinci-resolve
    discord
    lutris
    emojione
    darktable
    sbctl
    niv
    gnome-tweaks
    git
    tailscale
    zoom-us
    openssh
    cifs-utils
    vim
    kitty
    xclip
    tealdeer
    bat
    gitAndTools.gh
    # GNOME extension packages
    ext.dash-to-panel
  ];

  system.stateVersion = "25.05";
}
