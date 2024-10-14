args@{pkgs, disk, safeProductName, updateUrl, kioskUrl, ...}:
with builtins;
with pkgs.lib;
let
    overlayPath = "/tmp/playos-test-disk-overlay.qcow2";
    # fileFilter is recursive, so tests can in theory be in subfolders
    testFiles = fileset.fileFilter (file: file.hasExt "nix") ./tests;
    testPackages = map
        (file: pkgs.callPackage file
            (args // { inherit overlayPath; })
        )
        (fileset.toList testFiles);
    testDeriv = pkgs.linkFarmFromDrvs "out" testPackages;
    testInteractiveDeriv = pkgs.linkFarmFromDrvs "interactive"
        (map (t: t.driverInteractive) testPackages);
in
    {
        run-tests = testDeriv;
        interactive-tests = testInteractiveDeriv;
    }
