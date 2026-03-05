{
  description = "PlayOS metric dashboard";

  inputs = {
    # Grafana 12.2.x and 12.3.x releases have a regression that prevents saving
    # provisioned dashboards, see: https://github.com/grafana/grafana/issues/111525
    # Therefore nixpkgs cannot be bumped to 25.11 or unstable as of 2026-02-18
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        checkedScript = path: pkgs.writeShellApplication {
          name = "checked-${path}";
          text = builtins.readFile path;
        };
        checkedRunGrafana = checkedScript ./run-grafana;
        checkedExportDashboards = checkedScript ./export-dashboards;
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gnused
            jwt-cli
            openssl
            grafana
          ];
          # force shellcheck
          SHELLCHECK_COMPLETED = "${checkedRunGrafana} ${checkedExportDashboards}";
          GRAFANA_PKG_DIR = "${pkgs.grafana}";
        };

        checks = { inherit checkedRunGrafana checkedExportDashboards; };
      }
    );
}
