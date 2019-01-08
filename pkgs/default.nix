# overlay for custom packages
self: super: {

  rauc = (import ./rauc) super;

  dividat-driver = (import ./dividat-driver) {
    inherit (super) stdenv fetchurl;
  };

  # NetworkManager requires overriding to use dhcpcd
  networkmanager = super.networkmanager.overrideAttrs (oldAttrs: {

    patches = oldAttrs.patches ++ [ ./network-manager/enable-ipv4ll.patch ];

    configureFlags =
      (super.lib.remove "--with-dhcpcd=no" oldAttrs.configureFlags)
      ++ [ "--with-dhcpcd=${super.dhcpcd}/bin/dhcpcd" ];
  });

}
