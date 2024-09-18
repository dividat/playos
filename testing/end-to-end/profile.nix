{pkgs, ...}: {
    imports = [
      (pkgs.importFromNixos "modules/profiles/qemu-guest.nix")
      (pkgs.importFromNixos "modules/testing/test-instrumentation.nix")
    ];

    config = {
        # don't need opengl for running tests, reduces image size vastly
        hardware.opengl.enable = false;
    };
}
