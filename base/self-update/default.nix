{ config, pkgs, lib, ... }:
let
  cfg = config.playos.selfUpdate;

  # propagate status.ini update to legacy systems
  postInstallHandler = pkgs.writeShellApplication {
    name = "post-install";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
        tmpfile=$(mktemp)
        trap 'rm -f $tmpfile' EXIT

        cp -av /var/lib/rauc/status.ini "$tmpfile"
        # Ensure /boot/status.ini is always order than /var/lib/rauc/status.ini
        # to avoid statusfile-recovery.service from overwriting it. See below
        # for details.
        touch -a -m --date=@0 "$tmpfile"
        cp -av "$tmpfile" /boot/status.ini
        sync
    '';
  };
in
{
  imports = [ ../volatile-root.nix ];

  options = {
    playos.selfUpdate = with lib; {
      enable = mkEnableOption "Online self update";

      updateCert = mkOption {
        default = null;
        example = "path to public key";
        type = types.path;
        description = "The public key for the key bundles are signed with";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ rauc ];

    services.dbus.packages = with pkgs; [ rauc ];

    playos.storage.persistentFolders."/var/lib/rauc" = {
        mode = "0700";
        user = "root";
        group = "root";
    };

    systemd.services.rauc = {
      description = "RAUC Update Service";
      serviceConfig = {
        Type = "dbus";
        BusName= "de.pengutronix.rauc";
        ExecStart = "${pkgs.rauc}/bin/rauc service";
        User = "root";
        StateDirectory = "rauc";
      };
      wantedBy = [ "multi-user.target" ];
    };

    environment.etc."rauc/system.conf" = {
      text = ''
        [system]
        compatible=dividat-play-computer
        bootloader=grub
        grubenv=/boot/grub/grubenv
        statusfile=/var/lib/rauc/status.ini

        [keyring]
        path=cert.pem

        [slot.system.a]
        device=/dev/disk/by-label/system.a
        type=ext4
        bootname=a

        [slot.system.b]
        device=/dev/disk/by-label/system.b
        type=ext4
        bootname=b

        [handlers]
        post-install=${lib.getExe postInstallHandler}
      '';
    };

    environment.etc."rauc/cert.pem" = {
      source = cfg.updateCert;
    };


    # When one of the RAUC slots is legacy (meaning, RAUC state is persisted in
    # /boot/status.ini), we need to copy it over to /var/lib/rauc in case it is
    # newer than /var/lib/rauc/status.ini or if /var/lib/rauc/status.ini is
    # missing
    #
    # Before comparing the the modified times, we deal with the lack of
    # journalling/atomic writes on FAT32, by attempting to recover a partially
    # written /boot/status.ini.
    systemd.services.statusfile-recovery = {
      description = "status.ini recovery";
      # TODO: use pkgs.writeShellApplication
      serviceConfig.ExecStart = "${pkgs.bash}/bin/bash ${./recover-from-tmpfile} /boot/status.ini /var/lib/rauc/status.ini";
      serviceConfig.Type = "oneshot";
      serviceConfig.User = "root";
      serviceConfig.StandardOutput = "syslog";
      serviceConfig.SyslogIdentifier = "statusfile-recovery";
      serviceConfig.RemainAfterExit = true;
      after = [ "local-fs.target" ];
      before = [ "rauc.service" ];
      wantedBy = [ "multi-user.target" ];
    };

  };
}
