{pkgs, disk, safeProductName, updateUrl, kioskUrl, ...}:
with builtins;
with pkgs.lib;
let
    overlayPath = "/tmp/playos-test-disk-overlay.qcow2";
    # this is recursive, but whatever
    testFiles = fileset.fileFilter (file: file.hasExt "nix") ./tests;
    testPackages = map
        (file: pkgs.callPackage file
            # TODO: why does (args // {inherit overlayPath}) not work??
            { inherit overlayPath disk safeProductName updateUrl kioskUrl; }
        )
        (fileset.toList testFiles);
    # TODO: Currently this builds AND runs the tests, however
    # it might make sense to only build the tests and run them
    # as a separate step. The benefit of build+run is that Nix
    # knows what has changed and so which tests need to be re-build i.e. re-run.
    testDeriv = pkgs.linkFarmFromDrvs "out" testPackages;
    # TODO: how to always produce the interactive derivation even if
    # tests fail? useful for debugging
    testInteractiveDeriv = pkgs.linkFarmFromDrvs "interactive"
        (map (t: t.driverInteractive) testPackages);
in
    pkgs.linkFarmFromDrvs
        "end-to-end-tests"
        [
            testDeriv
            testInteractiveDeriv
        ]
