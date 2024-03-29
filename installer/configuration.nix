{ config, pkgs, lib, install-playos, version, safeProductName, fullProductName, greeting, ... }:

with lib;

{
  imports = [
    (pkgs.importFromNixos "modules/installer/cd-dvd/iso-image.nix")
  ];

  # Custom label when identifying OS
  system.nixos.label = "${safeProductName}-${version}";

  environment.systemPackages = [
    install-playos
  ];

  # Disable documentation
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  # Disable some other stuff we don't need.
  security.sudo.enable = mkDefault false;
  services.udisks2.enable = mkDefault false;

  # Automatically log in at the virtual consoles.
  services.getty.autologinUser = "root";

  # Allow the user to log in as root without a password.
  users.users.root.initialHashedPassword = "";

  services.getty.greetingLine = greeting "${fullProductName} installer (${version})";

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
    hostName = "${safeProductName}-installer";

    # enable wpa_supplicant
    wireless = {
      enable = true;
    };
  };

  # ISO naming.
  isoImage.isoName = "${safeProductName}-installer-${version}.iso";

  isoImage.volumeID = substring 0 11 "PLAYOS_ISO";

  # EFI booting
  isoImage.makeEfiBootable = true;

  # USB booting
  isoImage.makeUsbBootable = true;

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

  # There is no state living past a single boot into whichever version this was built with
  system.stateVersion = lib.trivial.release;

}
