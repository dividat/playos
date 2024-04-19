{ pkgs, config, lib, ... }:

let

  power-button-shutdown = pkgs.stdenv.mkDerivation {
    name = "power-button-shutdown";
    propagatedBuildInputs = [
      (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
        evdev
      ]))
    ];
    dontUnpack = true;
    installPhase = "install -Dm755 ${./power-button-shutdown.py} $out/bin/power-button-shutdown";
  };

in {

  # Ignore system control keys that do not make sense for kiosk applications
  services.logind.extraConfig = ''
    HandleSuspendKey=ignore
    HandleRebootKey=ignore
    HandleHibernateKey=ignore
    HandlePowerKey=ignore
    HandlePowerKeyLongPress=poweroff
    HandleRebootKeyLongPress=poweroff
    HandleSuspendKeyLongPress=poweroff
    HandleHibernateKeyLongPress=poweroff
  '';

  hardware.uinput.enable = lib.mkDefault true;

  systemd.services.power-button-shutdown = {
    enable = true;
    description = "Detect power off key press, by power button device only, then shutdown computer";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${power-button-shutdown}/bin/power-button-shutdown";
      Restart = "always";

      # Access to input devices without being root
      # DynamicUser = true; # Currently prevent to shutdown the system
      SupplementaryGroups = with config.users.groups; [ input.name uinput.name ];

      # Hardening, see https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/hardware/kanata.nix#L117
      # Not using DeviceAllow and DevicePolicy, as I couldn’t get access to device list with that.
      CapabilityBoundingSet = [ "" ];
      IPAddressDeny = [ "any" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      PrivateNetwork = true;
      PrivateUsers = true;
      ProcSubset = "pid";
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = [ "native" ];
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
      UMask = "0077";
    };
  };
}
