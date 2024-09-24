{ pkgs, config, lib, ... }:
let
    inherit (lib.lists) range subtractLists;
    allVTEs = range 1 12;
    activeVTEs = config.playos.xserver.activeVirtualTerminals;
    disabledVTEs = (subtractLists activeVTEs allVTEs);
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

    config = lib.mkIf (disabledVTEs != []) {
        environment.systemPackages = [ pkgs.xorg.xmodmap pkgs.gnugrep pkgs.gnused ];

        # This works by finding the keycodes that map to F1...F12 and
        # replacing any combinations in them that map to XF86Switch_VT_{N} to
        # F{N} for all the disabled VTEs.
        services.xserver.displayManager.sessionCommands = ''
            MODS=$(mktemp --tmpdir xmodmap-XXXX)
            for i in ${toString disabledVTEs}; do
                xmodmap -pke |
                    sed -E 's/[ ]+/ /g' | \
                    grep -E "keycode [0-9]+ = F$i .*XF86Switch_VT_$i" | \
                    sed "s/XF86Switch_VT_$i/F$i/g" \
                    >> $MODS
            done
            # sanity check
            test "$(wc -l < $MODS)" -eq "${toString (builtins.length disabledVTEs)}"
            xmodmap $MODS
            rm $MODS
        '';
    };
}
