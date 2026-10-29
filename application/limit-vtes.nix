# Prevent users switching from the Xsession to VTEs.
#
# Works by overriding the xkbdir of xserver and passing patched layouts.
{ pkgs, config, lib, ... }:
let
    inherit (lib) range subtractLists mkOption mkIf types;

    allVTEs = range 1 12;
    activeVTEs = config.playos.xserver.activeVirtualTerminals;
    disabledVTEs = (subtractLists activeVTEs allVTEs);

    # Created a patched copy of xkeyboard_config, disabling unwanted VTs.
    customXkbDir = pkgs.runCommand "playos-xkb-dir" {
      nativeBuildInputs = [ pkgs.xorg.lndir ];
    } ''
      mkdir -p $out

      # Shadow the original directory structure with symlinks
      lndir ${pkgs.xkeyboard_config}/etc/X11/xkb $out

      rm $out/symbols/srvr_ctrl
      cp ${pkgs.xkeyboard_config}/etc/X11/xkb/symbols/srvr_ctrl $out/symbols/srvr_ctrl
      chmod u+w $out/symbols/srvr_ctrl

      for i in ${toString disabledVTEs}; do
        if ! grep -qE "XF86_?Switch_VT_$i" $out/symbols/srvr_ctrl; then
          echo "Error: Pattern 'XF86_?Switch_VT_$i' not found. Upstream srvr_ctrl may have changed." >&2
          exit 1
        fi

        sed -i -E "s/XF86_?Switch_VT_$i/NoSymbol/g" $out/symbols/srvr_ctrl
      done
    '';
in
{
    options = {
      playos.xserver.activeVirtualTerminals = with lib.types; lib.mkOption {
        # prevent merging
        type = types.uniq (types.listOf (types.ints.between 1 12));
        default =  allVTEs;
        defaultText = "Defaults to [1 2 ... 12], which implies all VTEs are active.";
        example = [ 7 8 ];
        description =
          lib.mdDoc ''
          Restrict the directly accessible virtual terminal shortcuts
          (Ctrl-Alt-FN).

          The goal is primarily to limit possible cause of confusion for users,
          especially accidental activation of VT 12 instead of opening the
          PlayOS controller (Ctrl-Shift-F12).

          Note that this is only a usability measure, since once a non-Xserver
          VT has been switched to, VT switching is handled by the Linux kernel
          and thus no longer limited to our whitelist.
          '';
      };
    };

    config = mkIf (disabledVTEs != []) {
      services.xserver.xkb.dir = customXkbDir;
    };
}
