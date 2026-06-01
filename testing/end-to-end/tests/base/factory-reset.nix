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
    ps.playos-test-helpers
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
from playos_test_helpers import create_overlay, TestPrecondition, TestCheck
create_overlay("${disk}", "${overlayPath}")

# scenario is re-used in integration tests as well
${builtins.readFile ../../../integration/factory-reset-scenario.py}
'';

}
