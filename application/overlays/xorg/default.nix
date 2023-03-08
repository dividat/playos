{ activeVirtualTerminals }:
self: super: {

  # This patches Xserver to restrict the directly accessible virtual terminals (Ctrl-Alt-FN)

  # The goal is primarily to limit possible cause of confusion for users, especially
  # accidental activation of VT 12 instead of opening the PlayOS controller (Ctrl-Shift-F12).
  # 
  # The patch mimics the Xserver option `DontVTSwitch`, which disables VT switching entirely.
  # We limit action event processing at the same site in Xserver code by checking
  # the VT number.
  #
  # Note that while `DontVTSwitch` is considered a security measure, ours is foremost a
  # usability measure. Once a non-Xserver VT has been switched to, VT switching is handled by
  # the Linux kernel and thus no longer limited to our whitelist.

  xorg =
    let
      isActiveVTCondition =
        super.lib.concatMapStringsSep " || " (vtno: "vtno == ${builtins.toString vtno}") activeVirtualTerminals;
      # The patch needs to be created against https://gitlab.freedesktop.org/xorg/xserver/ checked out
      # to the version Nixpkgs references. This source file has changed at a very low frequency
      # throughout the past few years.
      vtPatch = builtins.toFile "limit-vts.patch" ''
        diff --git a/hw/xfree86/common/xf86Events.c b/hw/xfree86/common/xf86Events.c
        index 8a800bd8f..5f9c40788 100644
        --- a/hw/xfree86/common/xf86Events.c
        +++ b/hw/xfree86/common/xf86Events.c
        @@ -186,7 +186,7 @@ xf86ProcessActionEvent(ActionEvent action, void *arg)
                 if (!xf86Info.dontVTSwitch && arg) {
                     int vtno = *((int *) arg);
         
        -            if (vtno != xf86Info.vtno) {
        +            if (vtno != xf86Info.vtno && (${isActiveVTCondition})) {
                         if (!xf86VTActivate(vtno)) {
                             ErrorF("Failed to switch from vt%02d to vt%02d: %s\n",
                                    xf86Info.vtno, vtno, strerror(errno));

      '';
    in
    super.xorg // {
      xorgserver = self.lib.overrideDerivation super.xorg.xorgserver (old: {
        patches = (old.patches or []) ++ [ vtPatch ];
      });
    };

}
