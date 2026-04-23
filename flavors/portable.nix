let
  defaults = import ../application.nix;
in
{
    inherit (defaults) safeProductName version overlays greeting;

    fullProductName = "${defaults.fullProductName} (portable)";

    module = { config, lib, pkgs, ... }: {
      imports = [
        defaults.module
      ];

      # Do not hard-code HDMI as default
      hardware.pulseaudio = {
        extraConfig = lib.mkForce ''
          # Respond to changes in connected outputs
          load-module module-switch-on-port-available
          load-module module-switch-on-connect blacklist=""
        '';
      };

      # we do not expect a stable/permanent network connection
      playos.networking.watchdog.enable = lib.mkForce false;

      # metrics are optimized for specific hardware and stable setup, probably
      # not very useful for ad-hoc portable setups
      playos.monitoring.enable = lib.mkForce false;
    };
}
