{pkgs, disk, overlayPath, ...}:
pkgs.testers.runNixOSTest {
  name = "Factory reset works";

  nodes = {
    playos = { config, lib, pkgs, ... }:
    {
      imports = [
        (import ../../virtualisation-config.nix { inherit overlayPath; })
      ];
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
${builtins.readFile ../../../helpers/nixos-test-script-helpers.py}
create_overlay("${disk}", "${overlayPath}")

# scenario is re-used in integration tests as well
${builtins.readFile ../../../integration/factory-reset-scenario.py}
'';

}
