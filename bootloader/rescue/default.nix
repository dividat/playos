{ stdenv, lib
, application
, squashfsTools, closureInfo, makeInitrd, linkFarm
, importFromNixos
, writeScript, dialog
, vim, grub2_efi, rauc
, squashfsCompressionOpts ? "-comp xz -Xdict-size 100%"}:
with lib;
let
  nixos = importFromNixos "";

  rescue_kiosk = writeScript "rescue-kiosk.sh" ''
    # Setup a tempfile
    tempfile=`(tempfile) 2>/dev/null` || tempfile=/tmp/test$$
    trap "rm -f $tempfile" 0 $SIG_NONE $SIG_HUP $SIG_INT $SIG_QUIT $SIG_TERM

    while [ true ]
    do

      ${dialog}/bin/dialog --clear --title "" \
        --backtitle "${application.fullProductName} - Rescue System" \
        --nocancel \
        --menu "Please Select an action" 0 0 0 \
        "wipe-user-data" "Delete all user data." \
        "reboot" "Reboot immediately" \
        "shell" "Access shell" \
        2> $tempfile

      retval=$?

      if [ $retval -eq 0 ]; then
        selection=`cat $tempfile`
        clear
        case $selection in
          "wipe-user-data")
            mkfs.ext4 -F -L data /dev/disk/by-label/data
            ret_code=$?
            if [ $ret_code != 0 ]; then
              echo
              echo "ERROR: Wiping user data failed. Press enter to reboot."
              read
            fi
            reboot -f;;
          "reboot")
            reboot -f;;
          "shell")
            exit;;
        esac

      fi

    done

    exit
  '';

in
(nixos {
  configuration = {config,...}: {
    # disable installation of bootloader
    boot.loader.grub.enable = false;

    fileSystems = {
      "/" = {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

      "/nix/store" = {
        fsType = "squashfs";
        device = "../nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };
    };

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
      hostName = "${application.safeProductName}-rescue";
      # enable wpa_supplicant
      wireless = {
        enable = true;
      };
    };

    environment.systemPackages = [
      vim
      grub2_efi
      rauc
    ];

    # Set up automatic login and start a rescue kiosk
    users.users.root.initialHashedPassword = "";
    services.getty.autologinUser = "root";
    programs.bash.loginShellInit = ''
      ${rescue_kiosk}
    '';

    boot.initrd.availableKernelModules = [ "squashfs" ];
    boot.initrd.kernelModules = [ "loop" ];

    boot.initrd.postMountCommands = ''
      # copy stage-2-init to /init so that stage-1-init
      # can find it without kernel arguments
      cp /mnt-root/nix/store/init /mnt-root/init
    '';

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = stdenv.mkDerivation {
      name = "squashfs.img";

      nativeBuildInputs = [ squashfsTools ];

      buildCommand =
        ''
          closureInfo=${closureInfo { rootPaths = [ config.system.build.toplevel ]; }}

          # Include the stage-2-init at a relocatable position
          cp ${config.system.build.toplevel}/init init

          # Generate the squashfs image.
          mksquashfs init $(cat $closureInfo/store-paths) $out \
            -keep-as-directory -all-root -b 1048576 ${squashfsCompressionOpts}
        '';
    };

    # Create the initrd
    system.build.rescueRamdisk = makeInitrd {
      inherit (config.boot.initrd) compressor;
      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

      contents =
        [ { object = config.system.build.squashfsStore;
            symlink = "/nix-store.squashfs";
          }
        ];
    };

    system.build.rescueSystem = linkFarm "playos-rescue-system" [
      { name = "kernel"; path = "${config.system.build.kernel}/bzImage"; }
      { name = "initrd"; path = "${config.system.build.rescueRamdisk}/initrd"; }
    ];

    # There is no persistent state for the rescue system
    system.stateVersion = lib.trivial.release;

  };
  system = "x86_64-linux";
}).config.system.build.rescueSystem
