{ substituteAll
, version, keyring, unsignedRaucBundle
, rauc
}:
substituteAll {
  src = ./deploy-playos-update.py;
  inherit version keyring unsignedRaucBundle;
  inherit rauc;
}
