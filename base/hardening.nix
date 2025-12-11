/* Apply system hardening configuration.

This module acts as a convenient way of disabling a number of standard
NixOS/Linux functionalities that are not required for immutable kiosk
operation. The idea is to disable them for additional system hardening,
removing things that could do harm should the system fall into the hands of an
attacker despite intrusion protection.

It may be convenient to disable the hardening configuration during development
at times.

*/
{config, pkgs, lib, ... }:
let
  cfg = config.playos.hardening;
in
{
  options = {
    playos.hardening = with lib; {
      enable = mkEnableOption "Apply hardening options";
    };
  };

  config = lib.mkIf cfg.enable {
    # There is no need for sudo
    security.sudo.enable = lib.mkForce false;

    # Do not include default packages
    environment.defaultPackages = lib.mkForce [];

    # No emergency maintenance shell
    systemd.enableEmergencyMode = false;

  };
}
