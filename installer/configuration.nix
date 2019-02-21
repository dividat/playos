{ config, pkgs, lib, install-playos, version,... }:

with lib;

{
  # Force use of already overlayed nixpkgs in modules
  nixpkgs.pkgs = pkgs;

  imports = [
    (pkgs.importFromNixos "modules/installer/cd-dvd/iso-image.nix")
    (pkgs.importFromNixos "modules/profiles/minimal.nix")
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

  # Codename Dancing Bear
  services.mingetty.greetingLine =
  ''
                           _,-'^\
                       _,-'   ,\ )
                   ,,-'     ,'  d'
    ,,,           J_ \    ,'
   `\ /     __ ,-'  \ \ ,'
   / /  _,-'  '      \ \
  / |,-'             /  }
  (                 ,'  /
  '-,________         /
             \       /
              |      |
             /       |                Dividat PlayOS installer (${version})
            /        |
           /  /~\   (\/)
          {  /   \     }
          | |     |   =|
          / |      ~\  |
          J \,       (_o
           '"
  '';

  environment.loginShellInit = ''
    install-playos --reboot
  '';

  # Enable non-free firmware
  hardware.enableRedistributableFirmware = true;

  # Use ConnMan
  networking = {
    hostName = "playos-installer";
    connman = {
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
    # enable wpa_supplicant
    wireless = {
      enable = true;
      # Add a dummy network to make sure that wpa_supplicant.conf is created (see https://github.com/NixOS/nixpkgs/issues/23196)
      networks."12345-i-do-not-exist"= {};
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
