{ install-playos, squashfsCompressionOpts, systemMetadata, ... }:


{ config, modulesPath, lib, ... }:
with lib;
let
    safeProductName = "${systemMetadata.safeProductName}-installer";
    fullProductName = "${systemMetadata.fullProductName} Installer";
    # We version the installer according to the version of PlayOS it installs!
    version = systemMetadata.version;

    greeting = label: strings.escape [''\''] ''
                 _,_,_,_,
               .'########',
             ,#############'.
            |################'
           |  ################`
          /``  ################`
         /      ###############'
        o------~"/"/"""""\"\"""`
     *          ` `       ` `
      *
       ${label}
       ${strings.stringAsChars (char: "=") label}
    '';

in

{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
  ];

  # Custom label when identifying OS
  system.nixos.label = "${safeProductName}-${version}";

  environment.etc."os-release".text = lib.mkForce ''
    ID=${safeProductName}
    ID_LIKE="nixos"
    NAME="${fullProductName}"
    PRETTY_NAME="${fullProductName} ${version} (NixOS ${config.system.nixos.release} ${config.system.nixos.codeName})"
    VERSION="${version}"
    VERSION_ID="${version}"
    HOME_URL="https://github.com/dividat/playos"
    BUG_REPORT_URL="https://github.com/dividat/playos/issues"
  '';


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

  services.getty.greetingLine = greeting "${fullProductName} (${version})";

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
    hostName = "${safeProductName}";

    # enable wpa_supplicant
    wireless = {
      enable = true;
    };
  };

  isoImage = {
    isoName = "${safeProductName}-${version}.iso";
    volumeID = substring 0 11 "PLAYOS_ISO";
    makeEfiBootable = true;
    makeUsbBootable = true;
  } // lib.optionalAttrs (squashfsCompressionOpts != null)
        { squashfsCompression = squashfsCompressionOpts; };

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

  # There is no state living past a single boot into whichever version this was built with
  system.stateVersion = lib.trivial.release;

}
