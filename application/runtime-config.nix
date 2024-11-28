{ pkgs }:
with pkgs.lib;
let
    # "private" function
    generateTOML = fullConfig:
        let
            toml = (pkgs.formats.toml {});
        in
            toml.generate "config.toml" fullConfig;

    runtimeConfigType = types.submodule { options = {
        kiosk = {
            url = mkOption {
                type = types.nonEmptyStr;
                example = "http://play.dividat.com";
                description = "URL served by the Kiosk browser";
            };
            remote_debug_listen = mkOption {
                type = types.str;
                default = "127.0.0.1:3355";
                example = "0.0.0.0:3355";
                description = "TCP address for Qt WebEngine debug console";
            };
        };
        controller = {
            port = mkOption {
                type = types.port;
                default = 3333;
                description = "Listen port of playos-controller";
            };
        };
    }; };
in
rec {
    # Produces a TOML file from a partial runtime config by merging it with
    # defaults. Checks types via the module system.
    # Used in tests to produce an overlay config outside of the normal NixOS
    # module workflow.
    mergeAndGenTOML = partialConfig:
        let
            # see https://github.com/NixOS/nixpkgs/pull/42838 for a similar
            # approach to (ab)usage of modules for default merging and type checking
            fullConfig = (evalModules { modules = [ {
                config = { overlayCfg = partialConfig; };
                options = { overlayCfg = mkOption { type = runtimeConfigType; }; };
                _file = "overlay-config"; # only needed for err logs
            } ]; }).config.overlayCfg;
        in
            generateTOML fullConfig;

    module = { config, pkgs, lib, ... }: {
        options = {
            playos.runtimeConfig = {
                config = mkOption {
                    description = "PlayOS runtime configuration";
                    type = runtimeConfigType;
                };

                getValCmd = mkOption {
                    description = ''
                        Helper function that given an attrset path returns a
                        bash-snippet, which upon evaluation returns the provided
                        runtime config value. Validates that the provided path
                        corrends to an existing config key.
                    '';
                    readOnly = true;
                    type = types.functionTo types.str;
                };
            };
        };

        config = {
            environment.etc."playos-config.toml".source =
                generateTOML config.playos.runtimeConfig.config;

            playos.runtimeConfig.getValCmd = path: let
                containsPath = attrsets.hasAttrByPath
                    (strings.splitString "." path)
                    config.playos.runtimeConfig.config;
                in
                # dynamic type checking
                assert asserts.assertMsg containsPath
                   "playos.runtimeConfig.config config does not specify a value at '${path}', check names";
                "${pkgs.yq-go}/bin/yq eval -o toml -p toml .${path} /etc/playos-config.toml";
        };
    };
}
