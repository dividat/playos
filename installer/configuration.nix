{ config, pkgs, lib, install-playos, version, greeting, ... }:

with lib;

{
  # Force use of already overlayed nixpkgs in modules
  nixpkgs.pkgs = pkgs;

  imports = [
    (pkgs.importFromNixos "modules/installer/cd-dvd/iso-image.nix")
  ];

  environment.systemPackages = [
    install-playos
  ];

  # Disable some other stuff we don't need.
  security.sudo.enable = mkDefault false;
  services.udisks2.enable = mkDefault false;

  # Automatically log in at the virtual consoles.
  services.mingetty.autologinUser = "root";

  # Allow the user to log in as root without a password.
  users.users.root.initialHashedPassword = "";

  services.mingetty.greetingLine = greeting "Dividat PlayOS installer (${version})";

  environment.loginShellInit = ''
    install-playos --reboot
  '';

  # Enable non-free firmware
  hardware.enableRedistributableFirmware = true;

  # Use ConnMan
  services.connman = {
    enable = true;
    enableVPN = false;
    networkInterfaceBlacklist = [ "vmnet" "vboxnet" "virbr" "ifb" "ve" "zt" ];
    extraConfig = ''
      [General]
      AllowHostnameUpdates=false
      AllowDomainnameUpdates=false

      # Disable calling home
      EnableOnlineCheck=false
    '';
  };

  networking = {
    hostName = "playos-installer";

    # enable wpa_supplicant
    wireless = {
      enable = true;
    };
  };

  # ISO naming.
  isoImage.isoName = "playos-installer-${version}.iso";

  isoImage.volumeID = substring 0 11 "PLAYOS_ISO";

  # EFI booting
  isoImage.makeEfiBootable = true;

  # USB booting
  isoImage.makeUsbBootable = true;

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

}
