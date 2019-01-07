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
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOnzCRlk09MxWRc81VjKqwdSq2QiYMSz31wttDXj9Y5fufAoqfE+ytZgCwO6cVuamlquex6eiTJf3m+0RuUYKhdB4uhDlnzBoPOCM/AJBJwzOs6NOBWm4icZ7wzmZa5GMWJyzUklvIYFi0V5jOXMNWzf6hV4atkKpKVsZEDStWMGwbNdBSs37kkUwyvOh8DhtZYpzFEdiJNelYnI87Hd3KYl85sL6++7IukIILUTX7MytVxAOzs+uQWB0+od44ws19bBOOWowvCrOR14Hub1MJ547Dj9S6m9F4SR6DBIDLPmUi/xiov99Y5Z9HbP5b5/Qhm1+uQR8YnU+MRNdJ2c0c9dt/xH0IO8VwuWT1nhpO7AHH1jQPCNYzQcR05MGTFd2ZQgTkYpE2sHVzbRj+KxFX2OwYLfoWlGInAWnu4IqjNxzNunw02Zu16K4/uh6IAH/9JvlY7pLq0HaikAmpfrWvD7pLCqX3c1PKNBynSqEEf3ml7lq4pqumYgZGMSqnnkNavt6RNO5ZobUNR8KMqe9gUcKAkUhK7Hf925ideLFUVlL3FwweQMbpzHpGJ/6+t9n+/YtqxXLoqMthFwTeG85q/duBLe4O+9jFqXNajp1tCmSacD/j3pgeRLfzp1YmeMzJN6SIri9ojhOZiQPIA9UxVLwhuoGF6bBp94a/XDf26w== cardno:000605409732"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDUOwaIpDOHaADuJaS6+bSsEJDvmzRfdkhi8k/infDZimdbSRQvSdbRiRJlPPAeETRaKH8z5eOCJPYLSb3+EHn7oQFsUD6c5Gg+LQAahB/lhja7RoDCPH6/hHaOKYJny5lDfJ+KVSn3fNFiJ0mFJRIjGcoUeI95Rw1PHZJae8ZOapU336Uyy8hB84lvcaFmjzMEIyDkvSxpTrD+RpugG3XJhQE24a6t7fN9z3P6CfprVyFVHA3dkmxAvcYseeXA6TBfIGUbiC3wN1o7GoAgnsiVpwq9q4Ye3jMoRvB3Iw05rvcO/m5WT3JmCAWgeIM1yvWM3Pxc05E7g1jXRaygb0VVk8QendNZt+jlwVVU5N2H+LJ+vwyt+6PCFRGjPkLHjFwpoiLc7S6gHFQH4PcynyjOyAIKvBekn3LxV9hGkadVx7PwXX3C4Eqj4MGaVa095eVdtxZbSdwtUiOclXgA3G3O6Jen/fZDd2hMbX2mXgnGtn9LQjIz8RWFnyg6EU4ZfVhDsZcp8kVznQK8ibax2I++leJfVr95JsCPvVSIwNfxPA1/BDggxiwCSKUq/EvQyZ3/0pHJc3Lfca/1aTb0Hn1q5RPXjUGLlOOnG/yfD/FV1rnF49TgNIESF3tZ852Ba9sbcJohCgSCRBBeAiE7TXM5K84/V1HXlQlmA8JIJfyUlQ== openpgp:0x01C16138"
  ];
}
