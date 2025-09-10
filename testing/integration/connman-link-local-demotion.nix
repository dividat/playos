let
  pkgs = import ../../pkgs { };

  nodeFromNumber = nodeNumber: { config, ...}:
  let
    nodeNumberStr = toString nodeNumber;
  in
  {
    virtualisation.vlans = [ nodeNumber ];
    networking.firewall.enable = false;
    networking.dhcpcd.enable = false;
    networking.primaryIPAddress = "192.168.${nodeNumberStr}.${nodeNumberStr}";

    services.dnsmasq.enable = true;
    # do not auto-start
    systemd.services.dnsmasq.wantedBy = pkgs.lib.mkForce [ ];
    services.dnsmasq.settings = {
        dhcp-option = [
            "3,${config.networking.primaryIPAddress}" # self as gateway
            "6,${config.networking.primaryIPAddress}" # self as DNS
        ];
        dhcp-range = "192.168.${nodeNumberStr}.30,192.168.${nodeNumberStr}.99,1h";
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "connman link-local tests";

  nodes = {
    node1 = nodeFromNumber 1;
    node2 = nodeFromNumber 2;

    playos = { config, nodes, pkgs, lib, ... }: {
      config = {
        virtualisation.vlans = [ 1 2 ];

        networking.firewall.enable = false;

        services.connman = {
          enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default
          # ignore QEMU vnet
          networkInterfaceBlacklist = [ "eth0" ];

          extraFlags = [ "--debug=src/service.c" ];
          extraConfig = ''
              OnlineCheckMode=none
          '';
        };

      };
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = {nodes}:
let
    watchdogCfg = nodes.playos.playos.networking.watchdog;
in
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}

# ETH1 == connection to node1 via vlan1
# ETH2 == connection to node2 via vlan2

ETH1_SERVICE = "ethernet_525400120103_cable"
ETH2_SERVICE = "ethernet_525400120203_cable"

def configure_connman(flags):
    service = get_first_connman_service_name(playos)
    return playos.succeed(f"connmanctl config {service} {flags}")

node1.start()
node2.start()
playos.start()

with TestPrecondition("Booted and running"):
    playos.wait_for_unit('connman.service')
    playos.wait_for_unit("network-online.target")

# Restart connman to clear nixosTest vlan and DHCP IPs
playos.systemctl('restart connman.service')
time.sleep(2)

def check_if_linklocal(dev):
    addrs = playos.succeed(f"ip addr show dev {dev} | grep 'inet '")
    has_link_local = False

    for addr in addrs.strip().splitlines():
        if "169.254." in addr:
            has_link_local = True
        else:
            raise RuntimeError(f"{dev} has non-link-local addr: {addr}")

    if not has_link_local:
        raise RuntimeError(f"{dev} has no addresses: {addrs}")


def check_not_linklocal(dev):
    addrs = playos.succeed(f"ip addr show dev {dev} | grep 'inet '")

    has_addr = False
    for addr in addrs.strip().splitlines():
        if "169.254." in addr:
            raise RuntimeError(f"{dev} has link-local addr: {addr}")
        else:
            has_addr = True

    if not has_addr:
        raise RuntimeError(f"{dev} has no addresses: {addrs}")

with TestPrecondition("Wait until both ethernet services receive link-local addresses"):
    wait_until_passes(lambda: check_if_linklocal("eth1"), retries=10, sleep=5)
    wait_until_passes(lambda: check_if_linklocal("eth2"), retries=2, sleep=5)


# We have no way to control which interface will receive the link-local address
# first, so we check which was chosen as the default and deduce the secondary link
# from it
default_service = get_first_connman_service_name(playos)

if default_service == ETH1_SERVICE:
    secondary_vm = node2
    secondary_ip = "${nodes.node2.networking.primaryIPAddress}"
    secondary_dev = "eth2"
    secondary_service = ETH2_SERVICE
else:
    secondary_vm = node1
    secondary_ip = "${nodes.node1.networking.primaryIPAddress}"
    secondary_dev = "eth1"
    secondary_service = ETH1_SERVICE

secondary_vm.systemctl("start dnsmasq")
time.sleep(2)
secondary_vm.succeed("ip link set dev eth1 down")
secondary_vm.succeed("ip link set dev eth1 up")

with TestPrecondition("Wait until the secondary service receives a non-link-local address"):
    print("This can take a while...")
    wait_until_passes(lambda: check_not_linklocal(secondary_dev), retries=20, sleep=5)

time.sleep(1)

with TestCase("Confirm secondary service is now the default") as t:
    new_default_service = get_first_connman_service_name(playos)
    t.assertEqual(
        new_default_service,
        secondary_service,
        "Secondary service did not become the default!"
    )

with TestCase("Confirm secondary device has the default route") as t:
    default_route = playos.succeed("ip route | grep 'default via'").strip()
    t.assertEqual(
        default_route,
        f"default via {secondary_ip} dev {secondary_dev}",
        "Secondary service did not receive the default route!"
    )
'';
}
