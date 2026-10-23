# By default, Linux maps F13-F23 keys to various multimedia keys.
# Since we wish to use these as "special" shortcut keys in kiosk,
# we map them to "raw" key mappings
#
# Warning: if you wish to test this, QEMU's `sendkey` only works for F13-F15...
{config, pkgs, lib, ... }:
let
  xmodmapConfig = pkgs.writeText "restore-raw-f13-f23-keys" ''
    keycode 191 = F13 F13 F13
    keycode 192 = F14 F14 F14
    keycode 193 = F15 F15 F15
    keycode 194 = F16 F16 F16
    keycode 195 = F17 F17 F17
    keycode 196 = F18 F18 F18
    ! by default F19 is not mapped to anything
    keycode 197 = F19 F19 F19
    keycode 198 = F20 F20 F20
    keycode 199 = F21 F21 F21
    keycode 200 = F22 F22 F22
    keycode 201 = F23 F23 F23
  '';
in
{
  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xmodmap}/bin/xmodmap ${xmodmapConfig}
  '';
}
