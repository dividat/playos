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

          # Prevent PulseAudio from remembering previous muted states.
          # First, we unload the default restore module, then reload it
          # explicitly telling it NOT to restore mute states.
          unload-module module-device-restore
          load-module module-device-restore restore_volume=true restore_muted=false
        '';
      };

      systemd.user.services.force-unmute = {
        description = "Force unmute PulseAudio on login";
        wantedBy = [ "default.target" ];
        after = [ "pulseaudio.service" ];

        path = [ pkgs.pulseaudio ];

        script = ''
          # Brief pause to ensure PulseAudio has fully initialized its sinks
          sleep 2
          pactl set-sink-mute @DEFAULT_SINK@ 0

          # Optional: Force volume to a safe default so it is never at 0%
          pactl set-sink-volume @DEFAULT_SINK@ 70%
        '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      # we do not expect a stable/permanent network connection
      playos.networking.watchdog.enable = lib.mkForce false;

      # metrics are optimized for specific hardware and stable setup, probably
      # not very useful for ad-hoc portable setups
      playos.monitoring.enable = lib.mkForce false;

      # Add bindings for media keys to allow volume control
      environment.etc."sxhkd/sxhkdrc".text = ''
        XF86AudioLowerVolume
            ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%

        XF86AudioRaiseVolume
            ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%

        XF86AudioMute
            ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle
      '';

      services.xserver.displayManager.sessionCommands = ''
        ${pkgs.sxhkd}/bin/sxhkd -c /etc/sxhkd/sxhkdrc &
      '';
    };
}
