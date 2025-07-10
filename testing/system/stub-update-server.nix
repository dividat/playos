# The module also provides a stub update server service running on localhost
{ pkgs, config, options, modulesPath, ... }:
let
    cfg = config.playos.testing;
in
with pkgs;
with lib;
{
    options = {
      playos.testing.stubUpdateServer = {
        returnedVersion = mkOption {
            description = "What version will the stub server returns as the latest";
            default = "1.0.0";
            type = types.str;
        };

        port = mkOption {
            description = "HTTP port that the server will listen on";
            default = 9000;
            type = types.ints.positive;
        };
      };
    };


    config = {
        systemd.services.stub-update-server = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart =
              let
                respond =
                    ''echo -e "HTTP/1.1 200 OK\r\n" && echo "${cfg.stubUpdateServer.returnedVersion}"'';
              in
              "${pkgs.nmap}/bin/ncat -lk -p ${toString cfg.stubUpdateServer.port} -c '${respond}'";
            Restart = "always";
          };
        };
    };
}
