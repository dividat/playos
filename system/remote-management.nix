{config, pkgs, lib, ... }:
{
  # Enable ZeroTier for remote management
  services.zerotierone = {
    enable = true;
    # from the ext.dividat.com network.
    joinNetworks = [ "a09acf02330ccc60" ];
  };

  # Make the zerotier data directory persistent (on user data partition). This
  # means zerotier id of this machine will be persisted on updates but not when
  # wiping user data partition.
  volatileRoot.persistentFolders."/var/lib/zerotier-one/" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  # Allow remote access via OpenSSH
  services.openssh = {
    enable = true;

    # but not with password
    passwordAuthentication = false;
  };


  # only with these special keys:
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDUOwaIpDOHaADuJaS6+bSsEJDvmzRfdkhi8k/infDZimdbSRQvSdbRiRJlPPAeETRaKH8z5eOCJPYLSb3+EHn7oQFsUD6c5Gg+LQAahB/lhja7RoDCPH6/hHaOKYJny5lDfJ+KVSn3fNFiJ0mFJRIjGcoUeI95Rw1PHZJae8ZOapU336Uyy8hB84lvcaFmjzMEIyDkvSxpTrD+RpugG3XJhQE24a6t7fN9z3P6CfprVyFVHA3dkmxAvcYseeXA6TBfIGUbiC3wN1o7GoAgnsiVpwq9q4Ye3jMoRvB3Iw05rvcO/m5WT3JmCAWgeIM1yvWM3Pxc05E7g1jXRaygb0VVk8QendNZt+jlwVVU5N2H+LJ+vwyt+6PCFRGjPkLHjFwpoiLc7S6gHFQH4PcynyjOyAIKvBekn3LxV9hGkadVx7PwXX3C4Eqj4MGaVa095eVdtxZbSdwtUiOclXgA3G3O6Jen/fZDd2hMbX2mXgnGtn9LQjIz8RWFnyg6EU4ZfVhDsZcp8kVznQK8ibax2I++leJfVr95JsCPvVSIwNfxPA1/BDggxiwCSKUq/EvQyZ3/0pHJc3Lfca/1aTb0Hn1q5RPXjUGLlOOnG/yfD/FV1rnF49TgNIESF3tZ852Ba9sbcJohCgSCRBBeAiE7TXM5K84/V1HXlQlmA8JIJfyUlQ== openpgp:0x01C16138"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2DDIwIbkQdzAvi1nF9RQLW+NjOrYeaEqGsCxR1V1B5ZVX5QrZOSL0JqacthjeTRmhbe8GyEztldNijgPJURkm2uIO9svsJUYcIylExu6ZIuRFlMRwwXuFGP/Ej8ahpPNRKRs3Jc3vrWRkwisImolGTi/E4r205xlDUWXgqjj8Hqwsh6jc4wiyrUwSvUtQ0Gl5weR84AsFgNeaIw565pghFXx/3jmLzNvxBrY+FwDWAnRD0QNNupdjLqXow3/QTWVLaPiEIc6Y3WxvTRiJTRFf80QUOw0pqUzOiGqoqiebA8WE/4pafUAFbW+hbfQZoNCwoP35cBO/+GJUXgzs+4Q/ openpgp:0xD56EDA61"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXvP3MLATx2TybGzQ7AtWX5NsDl8SC/sL3kTR7VefOAZzxOlCi8hQjRGiAjEqESepx5VTOtDP1p1slhwjkTsPoUmLeZxpRCZfXS4CuXmdJHJ+tLkuDtYhJm6s4lcHByzv3ErE3MGIqTPE0f0meXd1WOCCOSk8BzCot7WmqIHo0VgPMDq9Hb/NSJDnzlL4aZG2yF2hfrmPV31caKMXYCWDVCZWsSPexCmmU10kWfoAYNFzaCrLczPaTsvPNopiobnQ4cmEQk/GDaWy2fobiU9g4/iYh9czGnJNeeaFAPkcr1ivBKmD5qTS613OJwXqnaQy0+rh/HxOoXMpZYH6Hv7uXmtA2PtGTL8Fum5KnCk+M+H/8ohyPluWRVueRUK9MOzIkIvA0HlF4TdTMR+qhBY/yp2RaDg5PDwKypFqZz1RG/lAhCxtTZspqT2NdFvLfcfpT6rqlI3kt+clNTloeprudfSAKfU/rtBGT9qZjCL9CgGE2HB/RhPaBA1NsFXevvLzsJbGQ7ebaCM0Bl6mFkBqS73zqSonz1GOkWkq4tMyO7LH2iW6RHSpKDyHaY4hDmiCHEx8xEH/OlI+6xz0jcVdxe6a6YUwzjIWYi0D457aEMh+G3VAwTRa4PMoNaJe+ynvnUXC5CGsX8iOwXe4vWodLLHtBGcOhWJUNFrQ1AloDnQ== openpgp:0xA3BCEAAB"
  ];
}
