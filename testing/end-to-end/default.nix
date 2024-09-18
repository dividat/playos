args@{pkgs, lib, qemu, disk, ...}:
let
    testPackages = [
        (pkgs.callPackage ./playos-basic.nix args)
    ];
    testDeriv = pkgs.symlinkJoin {
        name = "tests-out";
        paths = testPackages;
    };
    testInteractiveDeriv = pkgs.symlinkJoin {
        name = "tests-interactive";
        paths = map (t: t.driverInteractive) testPackages;
    };
in
    pkgs.symlinkJoin {
        name = "end-to-end-tests";
        paths = [ testDeriv testInteractiveDeriv ];
    }
