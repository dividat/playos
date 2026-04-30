{ pkgs, config, lib, ... }:

let

  user = "power-button-shutdown";
  group = "power-button-shutdown";

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

  # Ignore system control keys that do not make sense for kiosk applications.
  # Ignore power key as well, but set up a systemd service shutting down the
  # computer on Power Button key press.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandleRebootKey = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
    HandleRebootKeyLongPress = "poweroff";
    HandleSuspendKeyLongPress = "poweroff";
    HandleHibernateKeyLongPress = "poweroff";
  };

  users = {
    users.${user} = {
      description = "User executing power-button-shutdown.service";
      group = group;
      createHome = false;
      isSystemUser = true;
    };
    groups.${group} = {};
  };

  # Allow user of power-button-shutdown.service to shutdown the service
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "${user}" &&
          subject.isInGroup("${group}") &&
          action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "poweroff.target" &&
          action.lookup("verb") == "start") {
          return polkit.Result.YES;
        }
      })
    '';
  };

  systemd.services.power-button-shutdown = {
    enable = true;
    description = "Handle Power Button device key presses.";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${power-button-shutdown}/bin/power-button-shutdown";
      Restart = "always";

      User = user;
      Group = group;
      SupplementaryGroups = with config.users.groups; [ input.name ];

      # Hardening, see https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/hardware/kanata.nix#L117 for inspiration.
      # Not using DeviceAllow and DevicePolicy, as this prevent listing devices otherwise.
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
