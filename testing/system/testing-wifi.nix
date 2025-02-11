# Simulated wireless access points (via mac80211_hwsim + hostapd) for VM /
# testing purposes. Currently provided without DHCP and NAT, so the VM
# will loose internet connectivity if you connect to any of them.
#
# Note: it will take around a minute to connect to these APs because connman
# will wait for a (non-existent) DHCP response.
{lib, pkgs, config, ...}:
with lib;
let
  simulatedAPInterfaces = concatMap (radio: attrNames radio.networks)
    (attrValues config.services.hostapd.radios);
in
{ config = {
    networking.wireless.enable = true;
    services.connman.enable = true;

    # wlan1 is the client interface, wlan0* are the simulated APs
    networking.wireless.interfaces = [ "wlan1" ];

    # tell connman not to touch the simulated APs
    services.connman.networkInterfaceBlacklist = simulatedAPInterfaces;

    # enable 802.11 simulation
    boot.kernelModules = [ "mac80211_hwsim" ];

    systemd.services.hostapd = {
        preStart = "${pkgs.util-linux}/bin/rfkill unblock all";
    };

    services.hostapd = {
      enable = true;
      radios.wlan0 = {
        band = "2g";
        channel = 7;
        countryCode = "US";
        # wireless access points
        networks = {
          wlan0 = {
            ssid = "wpa3-wifi";
            bssid = "02:00:00:00:00:00";
            authentication = {
              mode = "wpa3-sae";
              saePasswords = [ { password = "wpa3-wifi"; } ];
            };
          };
          wlan0-1 = {
            ssid = "open-wifi";
            bssid = "02:00:00:00:00:01";
            authentication.mode = "none";
          };
          wlan0-2 = {
            ssid = "enterprise-wifi";
            bssid = "02:00:00:00:00:02";
            authentication.mode = "none"; # overridden by settings below
            settings = {
                wpa = 3;
                wpa_key_mgmt = "WPA-EAP";
                auth_algs = 3;

                ieee8021x = 1;
                eap_server = 0;
                auth_server_addr = "127.0.0.1";
                auth_server_port = 1812;
                auth_server_shared_secret = "secret";
            };
          };
        };
      };
    };
};}
