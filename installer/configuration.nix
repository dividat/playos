{ config, pkgs, lib, importFromNixos, install-playos, version,... }:

with lib;

{
  # Force use of already overlayed nixpkgs in modules
  nixpkgs.pkgs = pkgs;

  imports = [
    (importFromNixos "modules/installer/cd-dvd/iso-image.nix")
    (importFromNixos "modules/profiles/minimal.nix")
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

  # A custom greeting line
  services.mingetty.greetingLine =
  '' 

    _____  _              ____   _____ 
    |  __ \| |            / __ \ / ____|
    | |__) | | __ _ _   _| |  | | (___  
    |  ___/| |/ _` | | | | |  | |\___ \ 
    | |    | | (_| | |_| | |__| |____) |
    |_|    |_|\__,_|\__, |\____/|_____/ 
                     __/ |              
                    |___/               

  
  Dividat PlayOS installer (${version})

  '';

  environment.loginShellInit = ''
    install-playos --reboot
  '';

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
